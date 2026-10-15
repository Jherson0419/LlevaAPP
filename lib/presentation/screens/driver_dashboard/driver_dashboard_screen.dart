import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/routes/app_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/passenger_name_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/custom_map_markers.dart';
import '../../../core/utils/location_helper.dart';
import '../../../core/utils/vehicle_category_helper.dart';
import '../../../core/enums/client_vehicle_category.dart';
import '../../../data/datasources/remote/directions_service.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../../domain/entities/user.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/driver_profile/driver_profile_cubit.dart';
import '../../bloc/driver_stats/driver_stats_cubit.dart';
import '../../bloc/driver_stats/driver_stats_state.dart';
import '../../bloc/driver_wallet/driver_wallet_cubit.dart';
import '../../bloc/driver_status/driver_status_bloc.dart';
import '../../bloc/driver_status/driver_status_event.dart';
import '../../bloc/driver_status/driver_status_state.dart';
import '../../cubit/passenger_driver_mode_cubit.dart';
import '../../widgets/driver/driver_drawer.dart';
import '../../widgets/driver/driver_negotiating_card.dart';
import '../../widgets/ride_destination_display.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);

/// Panel principal del conductor con dos pestañas vivas: Inicio (saludo,
/// estado de trabajo, vehículo, resumen del día y promociones) y Mapa (mapa,
/// conectarse, solicitudes, negociación y viaje).
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

  // Pestaña actual: 0 Inicio, 1 Mapa (Soporte y Perfil abren pantallas).
  int _currentTab = 0;

  /// Estilo claro del mapa (assets/map_style.json).
  String? _mapStyle;

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

  /// Nivel, billetera, resumen de hoy e historial de Inicio. Lo crea y lo
  /// cierra esta pantalla; también lo recibe «Mi nivel».
  final DriverProfileCubit _profileCubit = di.sl<DriverProfileCubit>();

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
        _profileCubit.load(auth.user.id);
        context
            .read<DriverStatusBloc>()
            .add(RecoverDriverActiveRide(auth.user.id));
      }
      _loadCustomMapIcons(context);
      _loadMapStyle();
    });
  }

  Future<void> _loadCustomMapIcons(BuildContext context) async {
    BitmapDescriptor? car;
    BitmapDescriptor? origin;
    BitmapDescriptor? dest;
    try {
      car = await CustomMapMarkers.createDriverCarMarker();
    } catch (_) {}
    // Mismos pines «gota» que ve el pasajero: azul el recojo, rojo el destino.
    try {
      origin = await CustomMapMarkers.createPinMarker();
    } catch (_) {}
    try {
      dest = await CustomMapMarkers.createPinMarker(
        color: CustomMapMarkers.destPinColor,
      );
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
    _markers
        .removeWhere((m) => m.markerId == const MarkerId('driver_location'));
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
    _profileCubit.close();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;

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

  /// Estilo claro compartido con los mapas del pasajero (se pasa por
  /// `GoogleMap.style`).
  Future<void> _loadMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/map_style.json');
      if (mounted) setState(() => _mapStyle = style);
    } catch (_) {
      // Si falla la carga, el mapa usa el estilo por defecto.
    }
  }

  /// Ruta con el mismo trazo que ve el pasajero: halo translúcido debajo y
  /// línea azul encima.
  static Set<Polyline> _routePolylines(List<LatLng> points) {
    return {
      Polyline(
        polylineId: const PolylineId('route_shadow'),
        points: points,
        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
        width: 12,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
        geodesic: true,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppTheme.primaryBlue,
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
        geodesic: true,
      ),
    };
  }

  void _replaceRoutePolylines(List<LatLng> points) {
    _polylines.removeWhere(
      (p) =>
          p.polylineId == const PolylineId('route') ||
          p.polylineId == const PolylineId('route_shadow'),
    );
    _polylines.addAll(_routePolylines(points));
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
    final shouldAnimateNegotiatingEntry = animateNegotiatingEntry &&
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
        ? '${_etaMinutesFromKm(kmDriverToOrigin)} min · '
            '${_formatDistanceSmart(kmDriverToOrigin)}'
        : 'Recojo';
    final totalKmToDestination = kmOriginToDest + (kmDriverToOrigin ?? 0);
    final destTitle = '${_etaMinutesFromKm(totalKmToDestination)} min · '
        '${_formatDistanceSmart(totalKmToDestination)}';

    setState(() {
      _markers.clear();
      _polylines.clear();
      _upsertDriverLocationMarker();

      // Pines con la punta sobre el punto; el tiempo y la distancia van en
      // el panel inferior y en el globo al tocarlos.
      _markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: LatLng(origin.latitude, origin.longitude),
          anchor: const Offset(0.5, 1.0),
          icon: _originIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
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
          anchor: const Offset(0.5, 1.0),
          icon: _destIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: destTitle,
            snippet: 'Origen → destino',
          ),
        ),
      );

      // Tramo del conductor al recojo: línea discontinua.
      if (driver != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('driver_to_origin'),
            points: [driver, origin],
            color: const Color(0xFF00AA44),
            width: 4,
            patterns: [PatternItem.dash(18), PatternItem.gap(10)],
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
          setState(() => _replaceRoutePolylines(routePoints));
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
      _drawStraightLine(
        origin,
        routePoints.isNotEmpty ? routePoints.last : origin,
      );
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
    final step =
        (routePoints.length / totalFrames).ceil().clamp(1, routePoints.length);
    for (int i = step; i <= routePoints.length; i += step) {
      if (!mounted || animToken != _negotiatingAnimToken) return;
      final end = i > routePoints.length ? routePoints.length : i;
      final partial = routePoints.sublist(0, end);
      final progress = end / routePoints.length;
      final zoom = 16.7 - (progress * 2.6);

      setState(() => _replaceRoutePolylines(partial));

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
    setState(() => _replaceRoutePolylines([origin, destination]));

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

  static bool _isInTrip(DriverStatusState state) =>
      state is DriverOnTrip ||
      state is DriverArrivedAtPickup ||
      state is DriverTripInProgress;

  /// «Empezar a trabajar». Con documentos rechazados no deja conectarse y
  /// lleva a corregirlos (igual que el interruptor anterior).
  void _goOnline() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated &&
        _hasRejectedDocuments(authState.user)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa tus documentos: tienes archivos rechazados.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      context.push(AppRouter.driverRejectedDocsPath);
      return;
    }
    context.read<DriverStatusBloc>().add(const ToggleStatus());
  }

  void _goOffline() {
    context.read<DriverStatusBloc>().add(const ToggleStatus());
  }

  /// «Pedir un taxi»: pasa al modo pasajero (igual que el menú lateral).
  void _switchToPassenger() {
    context.read<PassengerDriverModeCubit>().setPassengerMode();
    context.go('/client-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final drawerWidth = MediaQuery.sizeOf(context).width * 0.78;
    final authState = context.watch<AuthBloc>().state;
    final hasRejectedDocuments =
        authState is AuthAuthenticated && _hasRejectedDocuments(authState.user);
    final canRequestTaxi = authState is AuthAuthenticated &&
        userCanTogglePassengerDriver(authState.user);

    return BlocBuilder<DriverStatusBloc, DriverStatusState>(
      builder: (context, blocState) {
        final immersiveMode = blocState is DriverNegotiating ||
            blocState is DriverWaitingForPassengerDecision;
        final inTrip = _isInTrip(blocState);
        // Las pestañas se ocultan al negociar y durante el viaje.
        final showTabBar = !immersiveMode && !inTrip;

        return BlocProvider<DriverProfileCubit>.value(
          value: _profileCubit,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.white,
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
            bottomNavigationBar: showTabBar
                ? _DriverTabBar(
                    currentTab: _currentTab,
                    onHomeTap: () => setState(() => _currentTab = 0),
                    onMapTap: () => setState(() => _currentTab = 1),
                    onSupportTap: () =>
                        context.push(AppRouter.driverSupportPath),
                    onProfileTap: () =>
                        context.push(AppRouter.driverProfilePath),
                  )
                : null,
            body: MultiBlocListener(
              listeners: [
                BlocListener<DriverStatusBloc, DriverStatusState>(
                  listenWhen: (prev, curr) =>
                      prev is DriverTripInProgress && curr is DriverOnline,
                  listener: (context, state) {
                    context.read<DriverStatsCubit>().refresh();
                    context.read<DriverWalletCubit>().refresh();
                    _profileCubit.refresh();
                  },
                ),
              ],
              child: BlocConsumer<DriverStatusBloc, DriverStatusState>(
                listener: _onDriverStateChanged,
                builder: (context, state) {
                  // Inicio y Mapa viven en un IndexedStack: el mapa (y la
                  // lectura de la ubicación al crearlo) existe aunque se esté
                  // en Inicio, y no se recrea al cambiar de pestaña.
                  return IndexedStack(
                    index: _currentTab == 1 ? 1 : 0,
                    children: [
                      _buildHomeTab(
                        context,
                        state,
                        hasRejectedDocuments: hasRejectedDocuments,
                        canRequestTaxi: canRequestTaxi,
                      ),
                      _buildMapTab(context, state),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pestaña Inicio: cabecera, estado de trabajo, vehículo, resumen del día
  /// y promociones.
  Widget _buildHomeTab(
    BuildContext context,
    DriverStatusState state, {
    required bool hasRejectedDocuments,
    required bool canRequestTaxi,
  }) {
    final online = state is! DriverOffline;
    final requests = state is DriverOnline ? _visibleRides(state).length : 0;
    return ColoredBox(
      color: Colors.white,
      // Deslizar hacia abajo recarga el nivel, la billetera y el historial.
      child: RefreshIndicator(
        color: _kBlue,
        onRefresh: () async {
          await Future.wait([
            _profileCubit.refresh(),
            context.read<DriverStatsCubit>().refresh(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _DriverHomeHeader(
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                onProfileTap: () => context.push(AppRouter.driverProfilePath),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _WorkStatusCard(
                      online: online,
                      requestCount: requests,
                      hasRejectedDocuments: hasRejectedDocuments,
                      onGoToMap: () => setState(() => _currentTab = 1),
                      onReviewDocuments: () =>
                          context.push(AppRouter.driverRejectedDocsPath),
                    ),
                    const SizedBox(height: 16),
                    _LevelCard(
                      onTap: () => context.push(
                        AppRouter.driverLevelPath,
                        extra: _profileCubit,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _VehicleCard(),
                    const SizedBox(height: 16),
                    const _WalletCard(),
                    const SizedBox(height: 16),
                    const _TodaySummaryCard(),
                    const SizedBox(height: 16),
                    const _TripHistorySection(),
                    if (canRequestTaxi && !online) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: _switchToPassenger,
                          icon: const Icon(
                            Icons.local_taxi_rounded,
                            size: 18,
                            color: _kTextMuted,
                          ),
                          label: const Text(
                            'Pedir un taxi',
                            style: TextStyle(fontSize: 13, color: _kTextMuted),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pestaña Mapa: mapa a pantalla completa, estado arriba y, abajo, el
  /// panel de la etapa (solicitudes, negociación, viaje) o el botón para
  /// conectarse / desconectarse.
  Widget _buildMapTab(BuildContext context, DriverStatusState state) {
    final immersiveMode = state is DriverNegotiating ||
        state is DriverWaitingForPassengerDecision;
    final topInset = MediaQuery.paddingOf(context).top;
    final panels = _buildMapPanels(context, state);
    return Stack(
      children: [
        Positioned.fill(child: _buildMap()),
        if (state is DriverWaitingForPassengerDecision)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: const Alignment(0, -0.25),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(
                'Se está ofreciendo tu tarifa de '
                'S/ ${state.submittedPrice.toStringAsFixed(2)},\n'
                'esperando respuesta del cliente...',
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
        if (!immersiveMode)
          Positioned(
            top: topInset + 8,
            left: 16,
            right: 16,
            child: _MapStatusHeader(
              state: state,
              onRecenter: _centerMapOnCurrentLocation,
            ),
          ),
        ...panels,
      ],
    );
  }

  /// Reacciones a cada cambio de estado (avisos y mapa), sin cambios
  /// respecto al diseño anterior.
  void _onDriverStateChanged(BuildContext context, DriverStatusState state) {
    // Negociación y viaje se ven en el mapa, y en esas etapas no hay
    // pestañas: si se estaba en Inicio (p. ej. al recuperar un viaje al
    // abrir la app) se pasa al mapa.
    final needsMap = state is DriverNegotiating ||
        state is DriverWaitingForPassengerDecision ||
        _isInTrip(state);
    if (needsMap && _currentTab != 1) {
      setState(() => _currentTab = 1);
    }
    if (state is DriverRequestExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppTheme.warningOrange,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (state is DriverOnline) {
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
      _clearMap();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modo No Disponible activado'),
          backgroundColor: AppTheme.unavailableGray,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (state is DriverNegotiating ||
        state is DriverWaitingForPassengerDecision) {
      final r = state is DriverNegotiating
          ? state.activeRide
          : (state as DriverWaitingForPassengerDecision).activeRide;
      _showRouteOnMap(
        LatLng(r.originLat, r.originLng),
        LatLng(r.destLat, r.destLng),
        animateNegotiatingEntry: true,
        rideIdForAnimation: r.id,
      );
    } else if (_isInTrip(state)) {
      _lastNegotiatingAnimatedRideId = null;
      _negotiatingAnimToken++;
      final ride = _tripRide(state)!;
      _showRouteOnMap(
        LatLng(ride.originLat, ride.originLng),
        LatLng(ride.destLat, ride.destLng),
      );
    } else {
      _lastNegotiatingAnimatedRideId = null;
      _negotiatingAnimToken++;
    }
  }

  static RideEntity? _tripRide(DriverStatusState state) {
    if (state is DriverOnTrip) return state.activeRide;
    if (state is DriverArrivedAtPickup) return state.activeRide;
    if (state is DriverTripInProgress) return state.activeRide;
    return null;
  }

  Widget _buildMap() {
    if (_mapError != null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: _kTextMuted),
            const SizedBox(height: 16),
            const Text(
              'Mapa no disponible',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _mapError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _kTextMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _mapError = null),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: CameraPosition(
        target: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(
                AppConstants.trujilloLatitude,
                AppConstants.trujilloLongitude,
              ),
        zoom: 15,
      ),
      style: _mapStyle,
      // Sin edificios 3D: al acercar se dibujan con lados sombreados
      // oscuros que rompen el estilo claro.
      buildingsEnabled: false,
      // La posición del conductor la marca el auto ([_carIcon]).
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      markers: _markers,
      polylines: _polylines,
    );
  }

  /// Panel inferior de la pestaña Mapa según el estado del conductor.
  List<Widget> _buildMapPanels(BuildContext context, DriverStatusState state) {
    double? distanceToPickupKm(RideEntity ride) {
      final p = _currentPosition;
      if (p == null) return null;
      return LocationHelper.calculateDistance(
        LatLng(p.latitude, p.longitude),
        LatLng(ride.originLat, ride.originLng),
      );
    }

    // Negociación y espera de la respuesta del pasajero.
    if (state is DriverNegotiating) {
      return [
        Align(
          alignment: Alignment.bottomCenter,
          child: DriverNegotiatingCard(
            activeRide: state.activeRide,
            currentOffer: state.currentOffer,
            isWaitingOnPassenger: false,
            distanceToPickupKm: distanceToPickupKm(state.activeRide),
          ),
        ),
      ];
    }
    if (state is DriverWaitingForPassengerDecision) {
      return [
        Align(
          alignment: Alignment.bottomCenter,
          child: DriverNegotiatingCard(
            activeRide: state.activeRide,
            currentOffer: state.submittedPrice,
            isWaitingOnPassenger: true,
            distanceToPickupKm: distanceToPickupKm(state.activeRide),
          ),
        ),
      ];
    }

    // Viaje: hacia el recojo, en el recojo y hacia el destino.
    final tripRide = _tripRide(state);
    if (tripRide != null) {
      return [
        Align(
          alignment: Alignment.bottomCenter,
          child: _buildTripPanel(context, state, tripRide),
        ),
      ];
    }

    // En línea con solicitudes: la lista (con «Desconectarme» dentro).
    if (state is DriverOnline && _visibleRides(state).isNotEmpty) {
      return [
        Align(
          alignment: Alignment.bottomCenter,
          child: _buildOnlinePanel(context),
        ),
      ];
    }

    // Sin solicitudes: el botón para conectarse o desconectarse.
    final online = state is DriverOnline;
    return [
      Positioned(
        left: 24,
        right: 24,
        bottom: 16,
        child: _WorkToggleButton(
          online: online,
          onTap: online ? _goOffline : _goOnline,
        ),
      ),
      // Encima del botón, un aviso de que se buscan pasajeros.
      if (online)
        Positioned(
          left: 24,
          right: 24,
          bottom: 88,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kBlue,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Buscando pasajeros cercanos...',
                    style: TextStyle(fontSize: 13, color: _kTextDark),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
  }

  /// Solicitudes que siguen vigentes (menos de [_requestExpiry]).
  List<RideEntity> _visibleRides(DriverOnline state) {
    final now = DateTime.fromMillisecondsSinceEpoch(
      _requestClockSec.value * 1000,
      isUtc: true,
    );
    return state.availableRides
        .where((r) => !_isRideExpired(r, now))
        .toList(growable: false);
  }

  Widget _buildOnlinePanel(BuildContext context) {
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.38;
    return _BottomPanel(
      children: [
        // Solicitudes cercanas, o la espera si aún no hay.
        ValueListenableBuilder<int>(
          valueListenable: _requestClockSec,
          builder: (context, nowSec, _) {
            final state = context.read<DriverStatusBloc>().state;
            if (state is! DriverOnline) return const SizedBox.shrink();
            final now = DateTime.fromMillisecondsSinceEpoch(
              nowSec * 1000,
              isUtc: true,
            );
            final rides = _visibleRides(state);
            if (rides.isEmpty) {
              return const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kBlue,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Buscando pasajeros cercanos...',
                    style: TextStyle(fontSize: 14, color: _kTextMuted),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rides.length == 1
                      ? '1 solicitud cercana'
                      : '${rides.length} solicitudes cercanas',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxListHeight),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      final ride = rides[index];
                      return _RideRequestItem(
                        ride: ride,
                        currentPosition: _currentPosition,
                        remainingTime: _remainingRequestTime(ride, now),
                        elapsedTime: _elapsedRequestTime(ride, now),
                        onTap: () => context
                            .read<DriverStatusBloc>()
                            .add(ReceiveRequest(ride)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _goOffline,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.power_settings_new_rounded,
                  color: _kTextMuted,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Desconectarme',
                  style: TextStyle(
                    fontSize: 14,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Panel del viaje: etapa, pasajero, tiempo estimado, ruta, tarifa y el
  /// botón de la etapa (mismos eventos que antes).
  Widget _buildTripPanel(
    BuildContext context,
    DriverStatusState state,
    RideEntity ride,
  ) {
    final bloc = context.read<DriverStatusBloc>();
    final String title;
    final String buttonLabel;
    final Color buttonColor;
    final IconData buttonIcon;
    final VoidCallback onAction;
    LatLng? etaTarget;
    String? etaPrefix;

    if (state is DriverOnTrip) {
      title = 'Camino al punto de recojo';
      buttonLabel = '¡Ya llegué!';
      buttonColor = _kBlue;
      buttonIcon = Icons.flag_rounded;
      onAction = () => bloc.add(const NotifyArrival());
      etaTarget = LatLng(ride.originLat, ride.originLng);
      etaPrefix = 'Recojo en';
    } else if (state is DriverArrivedAtPickup) {
      title = 'Pasajero en el punto de recojo';
      buttonLabel = 'Iniciar viaje';
      buttonColor = const Color(0xFF00AA44);
      buttonIcon = Icons.play_arrow_rounded;
      onAction = () => bloc.add(const StartTrip());
    } else {
      title = 'Viaje en curso';
      buttonLabel = 'Finalizar viaje';
      buttonColor = const Color(0xFFFF4444);
      buttonIcon = Icons.stop_rounded;
      onAction = () => bloc.add(const FinishTrip());
      etaTarget = LatLng(ride.destLat, ride.destLng);
      etaPrefix = 'Destino en';
    }

    String? etaText;
    final position = _currentPosition;
    if (etaTarget != null && position != null) {
      final km = LocationHelper.calculateDistance(
        LatLng(position.latitude, position.longitude),
        etaTarget,
      );
      etaText = '$etaPrefix ${_etaMinutesFromKm(km)} min · '
          '${_formatDistanceSmart(km)}';
    }

    final first = passengerFirstNameFromFullName(ride.clientFirstName.trim());
    final passengerName = first.isEmpty ? 'Pasajero' : first;
    final price = ride.finalPrice ?? ride.offeredPrice;

    return _BottomPanel(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _kTextDark,
          ),
        ),
        if (etaText != null) ...[
          const SizedBox(height: 4),
          Text(
            etaText,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _kBlue,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            ClipOval(
              child: _passengerAvatarOrPlaceholder(
                ride.clientProfilePicUrl,
                size: 40,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                passengerName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Tarifa acordada',
                  style: TextStyle(fontSize: 10, color: _kTextMuted),
                ),
                Text(
                  '${AppConstants.currencySymbol} ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EEFF)),
          ),
          child: Column(
            children: [
              _RoutePlaceRow(
                color: CustomMapMarkers.originPinColor,
                text: ride.originName.split('\n').first,
              ),
              const SizedBox(height: 8),
              _RoutePlaceRow(
                color: CustomMapMarkers.destPinColor,
                text: RideDestPayloadParts.parse(ride.destName).addressLine,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onAction,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: buttonColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(buttonIcon, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  buttonLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _hasRejectedDocuments(UserEntity user) {
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

  /// Tiempo desde la creación de la solicitud (0 → 15 min).
  Duration _elapsedRequestTime(RideEntity ride, DateTime nowUtc) {
    final elapsed = nowUtc.difference(ride.createdAt.toUtc());
    if (elapsed.isNegative) return Duration.zero;
    return elapsed > _requestExpiry ? _requestExpiry : elapsed;
  }
}

/// Panel blanco inferior con esquinas superiores redondeadas y el asa.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Cabecera de Inicio: foto (perfil), saludo, calificación y viajes de hoy,
/// notificaciones y menú.
class _DriverHomeHeader extends StatelessWidget {
  const _DriverHomeHeader({
    required this.onMenuTap,
    required this.onProfileTap,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Buenos días';
    if (hour >= 12 && hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        8,
        16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final user = authState is AuthAuthenticated ? authState.user : null;
          final fullName = user?.fullName.trim() ?? '';
          final firstName = fullName.isEmpty
              ? 'Conductor'
              : fullName.split(RegExp(r'\s+')).first;
          return Row(
            children: [
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBlue, width: 2),
                  ),
                  child: ClipOval(
                    child: _DriverAvatar(storagePath: user?.profilePicUrl),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${_greeting()}, ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF666666),
                            ),
                          ),
                          TextSpan(
                            text: firstName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kTextDark,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    BlocBuilder<DriverStatsCubit, DriverStatsState>(
                      builder: (context, stats) {
                        final rating = stats.rating;
                        return Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFFB800),
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating?.toStringAsFixed(1) ?? '—',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 12,
                              color: const Color(0xFFDDDDDD),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              stats.isLoading
                                  ? '... viajes hoy'
                                  : stats.trips == 1
                                      ? '1 viaje hoy'
                                      : '${stats.trips} viajes hoy',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _kTextMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                // Aún no hay notificaciones para el conductor.
                onPressed: () {},
                tooltip: 'Notificaciones',
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: _kTextDark,
                  size: 22,
                ),
              ),
              IconButton(
                onPressed: onMenuTap,
                tooltip: 'Menú',
                icon: const Icon(
                  Icons.menu_rounded,
                  color: _kTextDark,
                  size: 22,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Estado de trabajo en Inicio: en línea (con las solicitudes cercanas) o
/// desconectado, y el acceso al mapa, donde se conecta y se atienden los
/// viajes. Avisa si hay documentos rechazados.
class _WorkStatusCard extends StatelessWidget {
  const _WorkStatusCard({
    required this.online,
    required this.requestCount,
    required this.hasRejectedDocuments,
    required this.onGoToMap,
    required this.onReviewDocuments,
  });

  final bool online;
  final int requestCount;
  final bool hasRejectedDocuments;
  final VoidCallback onGoToMap;
  final VoidCallback onReviewDocuments;

  static const Color _green = Color(0xFF00AA44);

  @override
  Widget build(BuildContext context) {
    if (hasRejectedDocuments && !online) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCDD2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppTheme.errorRed,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tienes documentos rechazados. Corrígelos para conectarte.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark,
                ),
              ),
            ),
            TextButton(
              onPressed: onReviewDocuments,
              child: const Text('Revisar'),
            ),
          ],
        ),
      );
    }

    final String title;
    final String subtitle;
    if (!online) {
      title = 'Estás desconectado';
      subtitle = 'Ve al mapa y pulsa «Empezar a trabajar».';
    } else if (requestCount > 0) {
      title = 'Estás en línea';
      subtitle = requestCount == 1
          ? 'Tienes 1 solicitud cercana.'
          : 'Tienes $requestCount solicitudes cercanas.';
    } else {
      title = 'Estás en línea';
      subtitle = 'Buscando pasajeros cercanos...';
    }
    final accent = online ? _green : const Color(0xFFAAAAAA);

    return GestureDetector(
      onTap: onGoToMap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: online ? const Color(0xFFEFFAF2) : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: online ? const Color(0xFFC8EBD2) : const Color(0xFFEEEEEE),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _kTextMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Ir al mapa',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kBlue,
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kBlue, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Nivel del conductor con el avance al siguiente. Abre «Mi nivel».
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverProfileCubit, DriverProfileState>(
      builder: (context, state) {
        final level = VehicleCategoryHelper.getLevel(state.totalTrips);
        final remaining = level.remainingFor(state.totalTrips);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: level.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: level.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(level.icon, color: Colors.white, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nivel ${level.label}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!level.isMax)
                            Text(
                              remaining == 1
                                  ? 'Completa 1 viaje para ser '
                                      '${level.nextLevelName}'
                                  : 'Completa $remaining viajes para ser '
                                      '${level.nextLevelName}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
                if (!level.isMax) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.totalTrips == 1
                            ? '1 viaje'
                            : '${state.totalTrips} viajes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Meta: ${level.nextLevelTrips}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: level.progressFor(state.totalTrips),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Vehículo del conductor con su categoría (por antigüedad) y los datos
/// del perfil.
class _VehicleCard extends StatelessWidget {
  const _VehicleCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final category = VehicleCategoryHelper.getCategoryByYear(user?.carYear);
        final gradient = VehicleCategoryHelper.getCategoryGradient(category);
        String orDash(String? value) {
          final text = value?.trim() ?? '';
          return text.isEmpty ? '--' : text;
        }

        final name = [user?.carBrand, user?.carModel]
            .map((part) => part?.trim() ?? '')
            .where((part) => part.isNotEmpty)
            .join(' ');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        VehicleCategoryHelper.getCategoryName(category),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name.isEmpty ? 'Sin vehículo registrado' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _VehicleInfoChip(
                          icon: Icons.badge_outlined,
                          label: orDash(user?.carPlate),
                        ),
                        _VehicleInfoChip(
                          icon: Icons.calendar_today_rounded,
                          label: user?.carYear?.toString() ?? '--',
                        ),
                        _VehicleInfoChip(
                          icon: Icons.palette_outlined,
                          label: orDash(user?.carColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      size: 90,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    Icon(
                      Icons.directions_car_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Billetera: comisión por pagar a la plataforma, lo ganado hoy y los
/// viajes de hoy.
class _WalletCard extends StatelessWidget {
  const _WalletCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: BlocBuilder<DriverProfileCubit, DriverProfileState>(
        builder: (context, state) {
          final loading = state.isLoading;
          String money(double value) =>
              loading ? '...' : 'S/ ${value.toStringAsFixed(2)}';
          return Column(
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: _kBlue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Mi billetera',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WalletStat(
                    label: 'Comisión por pagar',
                    value: money(state.walletBalance),
                    color: const Color(0xFFFF8C00),
                    icon: Icons.receipt_long_rounded,
                  ),
                  const _StatDivider(height: 50),
                  _WalletStat(
                    label: 'Ganado hoy',
                    value: money(state.todayEarnings),
                    color: const Color(0xFF00AA44),
                    icon: Icons.today_rounded,
                  ),
                  const _StatDivider(height: 50),
                  _WalletStat(
                    label: 'Viajes hoy',
                    value: loading ? '...' : '${state.todayTrips}',
                    color: _kBlue,
                    icon: Icons.directions_car_rounded,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kTextDark,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: _kTextMuted),
          ),
        ],
      ),
    );
  }
}

/// Resumen de hoy: viajes, kilómetros aproximados y ganancias.
class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard();

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Fecha corta en español, p. ej. «15 oct».
  static String _todayLabel() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')} ${_months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: BlocBuilder<DriverProfileCubit, DriverProfileState>(
        builder: (context, state) {
          final loading = state.isLoading;
          return Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, color: _kBlue, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Resumen de hoy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextDark,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _todayLabel(),
                    style: const TextStyle(fontSize: 12, color: _kTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    icon: Icons.local_taxi_rounded,
                    label: 'Viajes',
                    value: loading ? '...' : '${state.todayTrips}',
                    color: _kBlue,
                  ),
                  const _StatDivider(color: Color(0xFFDDDDDD)),
                  _SummaryItem(
                    icon: Icons.route_rounded,
                    label: 'Km (aprox.)',
                    value: loading
                        ? '...'
                        : '${state.todayKm.toStringAsFixed(1)} km',
                    color: const Color(0xFF00AA44),
                  ),
                  const _StatDivider(color: Color(0xFFDDDDDD)),
                  _SummaryItem(
                    icon: Icons.payments_rounded,
                    label: 'Ganancias',
                    value: loading
                        ? '...'
                        : 'S/ ${state.todayEarnings.toStringAsFixed(2)}',
                    color: const Color(0xFFFFB800),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kTextDark,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: _kTextMuted),
          ),
        ],
      ),
    );
  }
}

/// Últimos viajes terminados (hasta 10).
class _TripHistorySection extends StatelessWidget {
  const _TripHistorySection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverProfileCubit, DriverProfileState>(
      builder: (context, state) {
        if (state.recentTrips.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Historial de viajes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${state.recentTrips.length} recientes',
                  style: const TextStyle(fontSize: 12, color: _kTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final trip in state.recentTrips) _TripHistoryRow(trip: trip),
          ],
        );
      },
    );
  }
}

/// Un viaje del historial: categoría pedida, destino, origen, fecha y hora,
/// monto y forma de pago.
class _TripHistoryRow extends StatelessWidget {
  const _TripHistoryRow({required this.trip});

  final RideEntity trip;

  static const List<String> _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// Categoría que pidió el pasajero, según la etiqueta de servicio del
  /// destino («[Servicio: Confort]»…); sin etiqueta, Estándar.
  static ClientVehicleCategory _categoryOf(List<String> tags) {
    for (final tag in tags) {
      final t = tag.toLowerCase();
      if (t.startsWith('confort')) return ClientVehicleCategory.comfort;
      if (t.startsWith('xl')) return ClientVehicleCategory.xl;
      if (t.startsWith('moto')) return ClientVehicleCategory.moto;
    }
    return ClientVehicleCategory.standard;
  }

  /// «Hoy 14:05», «Ayer 09:30» o «12 oct 18:20».
  static String _whenLabel(DateTime created) {
    final local = created.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Hoy $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Ayer $time';
    return '${local.day} ${_months[local.month - 1]} $time';
  }

  @override
  Widget build(BuildContext context) {
    final dest = RideDestPayloadParts.parse(trip.destName);
    final category = _categoryOf(dest.serviceTags);
    final destLine =
        dest.addressLine.trim().isEmpty ? 'Destino' : dest.addressLine;
    final originLine = trip.originName.split('\n').first.trim();
    final amount = trip.finalPrice ?? trip.offeredPrice;
    final pm = trip.paymentMethod.toLowerCase();
    final payment =
        pm == 'yape' ? 'Yape' : (pm == 'plin' ? 'Plin' : 'Efectivo');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: VehicleCategoryHelper.getCategoryGradient(category),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              category == ClientVehicleCategory.moto
                  ? Icons.two_wheeler_rounded
                  : Icons.directions_car_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  originLine.isEmpty ? 'Origen' : originLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _kTextMuted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFFAAAAAA),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _whenLabel(trip.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00AA44),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  payment,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoChip extends StatelessWidget {
  const _VehicleInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra superior del mapa: estado (en línea / desconectado / en viaje) y
/// botón para centrar el mapa en el conductor.
class _MapStatusHeader extends StatelessWidget {
  const _MapStatusHeader({required this.state, required this.onRecenter});

  final DriverStatusState state;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final online = state is! DriverOffline;
    final String label;
    if (state is DriverOffline) {
      label = 'Desconectado';
    } else if (state is DriverOnTrip ||
        state is DriverArrivedAtPickup ||
        state is DriverTripInProgress) {
      label = 'En viaje';
    } else {
      label = 'En línea — recibiendo solicitudes';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? const Color(0xFF00CC44) : const Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kTextDark,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRecenter,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: _kBlue,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón grande del mapa: verde «Empezar a trabajar» o rojo «Desconectarme».
class _WorkToggleButton extends StatelessWidget {
  const _WorkToggleButton({required this.online, required this.onTap});

  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = online
        ? const [Color(0xFFCC2200), Color(0xFFFF4444)]
        : const [Color(0xFF00AA44), Color(0xFF00CC55)];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.power_settings_new_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              online ? 'Desconectarme' : 'Empezar a trabajar',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto del conductor. `profile_pic_url` guarda una ruta de Storage (bucket
/// privado) o una URL antigua: se resuelve con StorageService.getSignedUrl.
class _DriverAvatar extends StatefulWidget {
  const _DriverAvatar({required this.storagePath});

  final String? storagePath;

  @override
  State<_DriverAvatar> createState() => _DriverAvatarState();
}

class _DriverAvatarState extends State<_DriverAvatar> {
  late Future<String?> _url = _resolve();

  Future<String?> _resolve() =>
      di.sl<StorageService>().getSignedUrl(widget.storagePath);

  @override
  void didUpdateWidget(covariant _DriverAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) _url = _resolve();
  }

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFEEF5FF),
      child: Center(
        child: Icon(Icons.person_rounded, color: _kBlue, size: 22),
      ),
    );
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return fallback;
        return Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => fallback,
        );
      },
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({
    this.height = 40,
    this.color = const Color(0xFFEEEEEE),
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: height, color: color);
  }
}

/// Fila de origen o destino con su punto de color.
class _RoutePlaceRow extends StatelessWidget {
  const _RoutePlaceRow({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 4, right: 10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        Expanded(
          child: Text(
            text.trim().isEmpty ? '—' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kTextDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra de pestañas del conductor, con el mismo estilo que la del pasajero.
class _DriverTabBar extends StatelessWidget {
  const _DriverTabBar({
    required this.currentTab,
    required this.onHomeTap,
    required this.onMapTap,
    required this.onSupportTap,
    required this.onProfileTap,
  });

  final int currentTab;
  final VoidCallback onHomeTap;
  final VoidCallback onMapTap;
  final VoidCallback onSupportTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DriverTabItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              isSelected: currentTab == 0,
              onTap: onHomeTap,
            ),
            _DriverTabItem(
              icon: Icons.map_rounded,
              label: 'Mapa',
              isSelected: currentTab == 1,
              onTap: onMapTap,
            ),
            _DriverTabItem(
              icon: Icons.headset_mic_rounded,
              label: 'Soporte',
              isSelected: currentTab == 2,
              onTap: onSupportTap,
            ),
            _DriverTabItem(
              icon: Icons.person_rounded,
              label: 'Perfil',
              isSelected: currentTab == 3,
              onTap: onProfileTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverTabItem extends StatelessWidget {
  const _DriverTabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _kBlue : const Color(0xFFAAAAAA);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kBlue,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fondo, borde y color de texto para el chip de pago de la solicitud.
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
        fill: Color(0xFFF3E5FF),
        border: Color(0xFFCE93D8),
        label: Color(0xFF6A1B9A),
      );
    case 'plin':
      return const _RideRequestChipPalette(
        fill: Color(0xFFE3F2FF),
        border: Color(0xFF90CAF9),
        label: Color(0xFF0277BD),
      );
    default:
      return const _RideRequestChipPalette(
        fill: Color(0xFFE8F5E9),
        border: Color(0xFFA5D6A7),
        label: Color(0xFF2E7D32),
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
    color: const Color(0xFFEEF5FF),
    alignment: Alignment.center,
    child: Icon(Icons.person_rounded, color: _kBlue, size: size * 0.55),
  );
}

/// Solicitud cercana en la lista del panel: pasajero, tiempo desde que se
/// pidió, distancia al recojo, precio, ruta y forma de pago.
class _RideRequestItem extends StatelessWidget {
  const _RideRequestItem({
    required this.ride,
    this.currentPosition,
    required this.remainingTime,
    required this.elapsedTime,
    required this.onTap,
  });

  final RideEntity ride;
  final Position? currentPosition;
  final Duration remainingTime;
  final Duration elapsedTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    double? distanceFromDriverKm;
    if (currentPosition != null) {
      distanceFromDriverKm = LocationHelper.calculateDistance(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        LatLng(ride.originLat, ride.originLng),
      );
    }
    final distanceToPickupText = distanceFromDriverKm != null
        ? 'A ${distanceFromDriverKm.toStringAsFixed(1)} km de ti'
        : 'A — km de ti';

    final first = passengerFirstNameFromFullName(ride.clientFirstName.trim());
    final firstName = first.isEmpty ? 'Pasajero' : first;
    final rating = ride.clientPassengerRating;

    final pm = ride.paymentMethod.toLowerCase().trim();
    final paymentLabel =
        pm == 'yape' ? 'Yape' : (pm == 'plin' ? 'Plin' : 'Efectivo');
    final payChip = _paymentChipPaletteFor(ride.paymentMethod);

    final destParts = RideDestPayloadParts.parse(ride.destName);
    final destLine =
        destParts.addressLine.trim().isEmpty ? '—' : destParts.addressLine;

    final elapsedSecs = elapsedTime.inSeconds.clamp(0, 15 * 60);
    final emins = (elapsedSecs ~/ 60).toString().padLeft(2, '0');
    final esecs = (elapsedSecs % 60).toString().padLeft(2, '0');
    final urgent = remainingTime <= const Duration(minutes: 2);
    final timeColor = urgent ? AppTheme.errorRed : AppTheme.warningOrange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8EEFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: _passengerAvatarOrPlaceholder(
                        ride.clientProfilePicUrl,
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            firstName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kTextDark,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFB800),
                                size: 13,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${rating?.toStringAsFixed(1) ?? '—'} · '
                                '${ride.clientCompletedTrips} viajes',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${AppConstants.currencySymbol} '
                          '${ride.offeredPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _kBlue,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: timeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$emins:$esecs',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: timeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  distanceToPickupText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00AA44),
                  ),
                ),
                const SizedBox(height: 6),
                _RoutePlaceRow(
                  color: CustomMapMarkers.originPinColor,
                  text: ride.originName.split('\n').first,
                ),
                const SizedBox(height: 4),
                _RoutePlaceRow(
                  color: CustomMapMarkers.destPinColor,
                  text: destLine,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: payChip.fill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: payChip.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        pm == 'efectivo' || pm.isEmpty
                            ? Icons.payments_rounded
                            : Icons.qr_code_rounded,
                        size: 12,
                        color: payChip.label,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        paymentLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: payChip.label,
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
