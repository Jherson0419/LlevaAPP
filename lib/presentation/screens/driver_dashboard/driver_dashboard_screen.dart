import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/location_helper.dart';
import '../../../core/utils/marker_helper.dart';
import '../../../data/datasources/remote/directions_service.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../bloc/auth/auth_bloc.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  GoogleMapController? _mapController;
  String? _mapError;
  
  // Control de pestañas
  int _currentTabIndex = 0;
  
  // Ubicación actual del conductor
  Position? _currentPosition;
  
  // Marcadores y polylines del mapa
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  // Servicio de direcciones
  final DirectionsService _directionsService = DirectionsService();

  // ignore: unused_field — asset cargado por requisito UI; el mapa usa myLocation para el propio vehículo
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destIcon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        context.read<DriverStatsCubit>().loadTodayStats(auth.user.id);
        context.read<DriverWalletCubit>().loadWallet(auth.user.id);
      }
      _loadCustomMapIcons(context);
    });
  }

  Future<void> _loadCustomMapIcons(BuildContext context) async {
    BitmapDescriptor? car;
    BitmapDescriptor? origin;
    BitmapDescriptor? dest;
    final originDestPx =
        MarkerHelper.originDestIconWidthPx(MediaQuery.devicePixelRatioOf(context));
    try {
      car = await MarkerHelper.getBytesFromAsset('assets/icons/car.png', 100);
    } catch (_) {}
    try {
      origin = await MarkerHelper.getBytesFromAsset(
        'assets/icons/origin.png',
        originDestPx,
      );
    } catch (_) {}
    try {
      dest = await MarkerHelper.getBytesFromAsset(
        'assets/icons/dest.png',
        originDestPx,
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _carIcon = car;
      _originIcon = origin;
      _destIcon = dest;
    });
    _redrawActiveRouteIfAny();
  }

  void _redrawActiveRouteIfAny() {
    if (!mounted) return;
    final s = context.read<DriverStatusBloc>().state;
    if (s is DriverNegotiating) {
      final r = s.activeRide;
      _showRouteOnMap(
        LatLng(r.originLat, r.originLng),
        LatLng(r.destLat, r.destLng),
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
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    _setMapStyle();
    setState(() {
      _mapError = null;
    });

    // Obtener ubicación real del dispositivo
    try {
      final position = await LocationHelper.determinePosition();
      setState(() {
        _currentPosition = position;
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

  void _setMapStyle() {
    // Estilo oscuro para Google Maps
    const darkMapStyle = '''
    [
      {
        "elementType": "geometry",
        "stylers": [{"color": "#212121"}]
      },
      {
        "elementType": "labels.icon",
        "stylers": [{"visibility": "off"}]
      },
      {
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#212121"}]
      },
      {
        "featureType": "administrative",
        "elementType": "geometry",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "administrative.country",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#9e9e9e"}]
      },
      {
        "featureType": "administrative.locality",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#bdbdbd"}]
      },
      {
        "featureType": "poi",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "geometry",
        "stylers": [{"color": "#181818"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "poi.park",
        "elementType": "labels.text.stroke",
        "stylers": [{"color": "#1b1b1b"}]
      },
      {
        "featureType": "road",
        "elementType": "geometry.fill",
        "stylers": [{"color": "#2a2a2a"}]
      },
      {
        "featureType": "road",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#8a8a8a"}]
      },
      {
        "featureType": "road.arterial",
        "elementType": "geometry",
        "stylers": [{"color": "#373737"}]
      },
      {
        "featureType": "road.highway",
        "elementType": "geometry",
        "stylers": [{"color": "#3c3c3c"}]
      },
      {
        "featureType": "road.highway.controlled_access",
        "elementType": "geometry",
        "stylers": [{"color": "#4e4e4e"}]
      },
      {
        "featureType": "road.local",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#616161"}]
      },
      {
        "featureType": "transit",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#757575"}]
      },
      {
        "featureType": "water",
        "elementType": "geometry",
        "stylers": [{"color": "#000000"}]
      },
      {
        "featureType": "water",
        "elementType": "labels.text.fill",
        "stylers": [{"color": "#3d3d3d"}]
      }
    ]
    ''';

    _mapController?.setMapStyle(darkMapStyle);
  }

  /// ETA aproximada en minutos (velocidad media 30 km/h).
  int _etaMinutesFromKm(double distanceKm) {
    return (distanceKm / 30.0 * 60.0).ceil().clamp(1, 999);
  }

  void _tryShowOriginInfoWindow() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _mapController == null) return;
      try {
        await _mapController!.showMarkerInfoWindow(const MarkerId('origin'));
      } catch (_) {}
    });
  }

  /// Muestra la ruta en el mapa con marcadores y polyline
  /// Obtiene la ruta real usando Google Maps Directions API
  Future<void> _showRouteOnMap(LatLng origin, LatLng destination) async {
    final kmOriginToDest =
        LocationHelper.calculateDistance(origin, destination);
    final minOriginToDest = _etaMinutesFromKm(kmOriginToDest);

    double? kmDriverToOrigin;
    int? minDriverToOrigin;
    if (_currentPosition != null) {
      final driver = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      kmDriverToOrigin = LocationHelper.calculateDistance(driver, origin);
      minDriverToOrigin = _etaMinutesFromKm(kmDriverToOrigin);
    }

    final originTitle = kmDriverToOrigin != null && minDriverToOrigin != null
        ? 'A $minDriverToOrigin min (${kmDriverToOrigin.toStringAsFixed(1)} km)'
        : 'Recojo';

    final destTitle =
        '$minOriginToDest min (${kmOriginToDest.toStringAsFixed(1)} km)';

    setState(() {
      _markers.clear();
      _polylines.clear();

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
    });

    _tryShowOriginInfoWindow();

    // Intentar obtener la ruta real de Google Maps
    try {
      final routePoints = await _directionsService.getRouteCoordinates(
        origin,
        destination,
        AppConstants.googleMapsApiKey,
      );

      // Si se obtuvo la ruta exitosamente, dibujarla
      if (routePoints.isNotEmpty) {
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

        // Ajustar cámara para mostrar toda la ruta
        _adjustCameraToFitRoute(routePoints);
      } else {
        // Si no hay puntos, usar línea recta como fallback
        _drawStraightLine(origin, destination);
      }
    } catch (e) {
      // Si hay error, usar línea recta como fallback
      print('Error al obtener la ruta: $e');
      _drawStraightLine(origin, destination);
    }
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
    final drawerWidth = MediaQuery.sizeOf(context).width * 0.78;

    return BlocBuilder<DriverStatusBloc, DriverStatusState>(
      builder: (context, blocState) {
        final immersiveMode = blocState is DriverNegotiating;
        final bottomNavHeight = immersiveMode ? 0.0 : 56.0;

        return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.darkBackground,
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
            if (state is DriverOnline) {
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
            } else if (state is DriverNegotiating) {
              // Mostrar ruta en el mapa cuando se está negociando
              final origin = LatLng(state.activeRide.originLat, state.activeRide.originLng);
              final destination = LatLng(state.activeRide.destLat, state.activeRide.destLng);
              _showRouteOnMap(origin, destination);
            } else if (state is DriverOnTrip ||
                state is DriverArrivedAtPickup ||
                state is DriverTripInProgress) {
              final ride = state is DriverOnTrip
                  ? state.activeRide
                  : state is DriverArrivedAtPickup
                      ? state.activeRide
                      : (state as DriverTripInProgress).activeRide;
              final origin = LatLng(ride.originLat, ride.originLng);
              final destination = LatLng(ride.destLat, ride.destLng);
              _showRouteOnMap(origin, destination);
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
                              const Icon(
                                Icons.map_outlined,
                                size: 64,
                                color: AppTheme.darkTextSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Mapa no disponible',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: AppTheme.darkText,
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
                         myLocationEnabled: true,
                         myLocationButtonEnabled: false,
                         zoomControlsEnabled: false,
                         mapToolbarEnabled: false,
                         markers: _markers,
                         polylines: _polylines,
                         onCameraIdle: () {
                           // Mapa cargado correctamente
                         },
                       ),

                if (state is DriverNegotiating &&
                    state.awaitingPassengerResponse)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      alignment: const Alignment(0, -0.25),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'Se está ofreciendo tu tarifa de S/ ${state.currentOffer.toStringAsFixed(2)},\nesperando respuesta del cliente...',
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
                
                // Toggle de disponibilidad en la parte superior
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _buildAvailabilityToggle(context, state),
                    ),
                  ),
                ),

                // FAB del menú en la parte superior izquierda (siempre visible)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, left: 16),
                      child: FloatingActionButton(
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        backgroundColor: AppTheme.darkSurface,
                        mini: true,
                        child: const Icon(
                          Icons.more_vert,
                          color: AppTheme.darkText,
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

                // Tarjeta de negociación (si está negociando)
                if (state is DriverNegotiating)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: DriverNegotiatingCard(
                      state: state,
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
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        boxShadow: [
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
        backgroundColor: AppTheme.darkSurface,
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
    if (state is DriverNegotiating) {
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
    if (state is DriverOffline) {
      return Container(
        margin: EdgeInsets.only(bottom: bottomBarHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withOpacity(0.95),
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
                color: AppTheme.darkTextSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Conéctate para ver solicitudes',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.darkText,
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
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        margin: EdgeInsets.only(bottom: bottomBarHeight),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface.withOpacity(0.95),
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
                          color: AppTheme.darkText,
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
              child: BlocBuilder<DriverStatusBloc, DriverStatusState>(
                builder: (context, state) {
                  if (state is DriverOnline) {
                    final rides = state.availableRides;
                    
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
                                color: AppTheme.darkTextSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay solicitudes cercanas',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AppTheme.darkTextSecondary,
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
                          onTap: () {
                            context.read<DriverStatusBloc>().add(
                                  ReceiveRequest(ride),
                                );
                          },
                        );
                      },
                    );
                  }
                  
                  return const SizedBox.shrink();
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
    return Container(
      margin: EdgeInsets.only(bottom: bottomBarHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface.withOpacity(0.95),
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
                    color: AppTheme.darkText,
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
        color: AppTheme.darkSurface.withOpacity(0.96),
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
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: AppTheme.darkTextSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pasajero: $passengerRef',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.darkTextSecondary,
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
                          color: AppTheme.darkText,
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
                const Text(
                  'Tarifa acordada:',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
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
    final isNegotiating = state is DriverNegotiating;
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
      chipLabel = 'Negociando';
    } else if (isInTrip) {
      chipLabel = 'En viaje';
    } else if (state is DriverOnline) {
      chipLabel = 'Disponible';
    } else {
      chipLabel = 'No Disponible';
    }

    return GestureDetector(
      onTap: () {
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

  Widget _buildStatsWidget() {
    return BlocBuilder<DriverStatsCubit, DriverStatsState>(
      builder: (context, statsState) {
        final earningsText = statsState.isLoading
            ? '...'
            : '${AppConstants.currencySymbol} ${statsState.earnings.toStringAsFixed(2)}';
        final tripsText =
            statsState.isLoading ? '...' : '${statsState.trips}';
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withOpacity(0.95),
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
                color: AppTheme.darkTextSecondary.withOpacity(0.3),
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

_RideRequestChipPalette _serviceTagChipPaletteFor(String tag) {
  final n = tag.toLowerCase();
  if (n.contains('más de 4') ||
      n.contains('mas de 4') ||
      n.contains('4 pasajeros')) {
    return const _RideRequestChipPalette(
      fill: Color(0xFFE65100),
      border: Color(0xFFFFB74D),
      label: Colors.white,
    );
  }
  if (n.contains('xl') || n.contains('6 pax')) {
    return const _RideRequestChipPalette(
      fill: Color(0xFF4527A0),
      border: Color(0xFFB39DDB),
      label: Colors.white,
    );
  }
  if (n.contains('confort')) {
    return const _RideRequestChipPalette(
      fill: Color(0xFFF9A825),
      border: Color(0xFFFFEE58),
      label: Color(0xFF3E2723),
    );
  }
  if (n.contains('silla') || n.contains('bebé') || n.contains('bebe')) {
    return const _RideRequestChipPalette(
      fill: Color(0xFFC2185B),
      border: Color(0xFFF48FB1),
      label: Colors.white,
    );
  }
  if (n.contains('mascota')) {
    return const _RideRequestChipPalette(
      fill: Color(0xFF5D4037),
      border: Color(0xFFD7CCC8),
      label: Colors.white,
    );
  }
  return const _RideRequestChipPalette(
    fill: Color(0xFF37474F),
    border: Color(0xFF90A4AE),
    label: Color(0xFFECEFF1),
  );
}

// Widget para cada item de solicitud
class _RideRequestItem extends StatelessWidget {
  final RideEntity ride;
  final Position? currentPosition;
  final VoidCallback onTap;

  const _RideRequestItem({
    required this.ride,
    this.currentPosition,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cardBg = Color(0xFF1A1A1A);
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

    final firstName = ride.clientFirstName.trim().isEmpty
        ? 'Pasajero'
        : ride.clientFirstName.trim();

    final pm = ride.paymentMethod.toLowerCase().trim();
    final bool isYape = pm == 'yape';
    final bool isPlin = pm == 'plin';
    final String paymentLabel =
        isYape ? 'Yape' : (isPlin ? 'Plin' : 'Efectivo');

    final destParts = RideDestPayloadParts.parse(ride.destName);
    final destLine =
        destParts.addressLine.trim().isEmpty ? '—' : destParts.addressLine;

    final payChip = _paymentChipPaletteFor(ride.paymentMethod);

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
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.darkSurfaceElevated,
                          child: const Icon(
                            Icons.person,
                            color: AppTheme.darkTextSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        firstName,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.darkText,
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
                              style: const TextStyle(
                                color: AppTheme.darkText,
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
                              style: const TextStyle(
                                color: AppTheme.darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
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
                          if (destParts.serviceTags.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                alignment: WrapAlignment.start,
                                children: destParts.serviceTags
                                    .map(
                                      (t) {
                                        final pal =
                                            _serviceTagChipPaletteFor(t);
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pal.fill
                                                .withValues(alpha: 0.88),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: pal.border,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Text(
                                            t,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: pal.label,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (destParts.notes != null &&
                          destParts.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          destParts.notes!.trim(),
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                      if (ride.clientPassengerRating != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 18,
                              color: Colors.amber.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ride.clientPassengerRating!
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppTheme.darkText,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
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
