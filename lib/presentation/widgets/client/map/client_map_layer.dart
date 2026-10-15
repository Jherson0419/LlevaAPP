import 'dart:async';
import 'dart:developer' show log;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/enums/client_ride_status.dart';
import '../../../../core/services/places_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/custom_map_markers.dart';
import '../../../../core/utils/location_helper.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';
import 'center_pin_painter.dart';

/// Valor de `_originIconLabelKey` cuando el ícono de origen ya es el pin
/// «gota» azul.
const String _kOriginPinIconKey = 'teardrop-pin';

/// Ídem para el pin rojo de destino.
const String _kDestPinIconKey = 'teardrop-pin-dest';

/// Pausa entre mostrar origen y destino y empezar a dibujar la ruta.
const Duration _kRouteRevealDelay = Duration(seconds: 2);

/// Capa de mapa aislada: marcadores, polilíneas y cámara sin `setState` en el dashboard.
class ClientMapLayer extends StatefulWidget {
  const ClientMapLayer({
    super.key,
    required this.mapGestureActiveNotifier,
    required this.searchPulseController,
    required this.originFocusNode,
    required this.destFocusNode,
    this.allowPinSelection = true,
    this.routePadding = EdgeInsets.zero,
    this.editDestination = false,
  });

  final ValueNotifier<bool> mapGestureActiveNotifier;
  final AnimationController searchPulseController;
  final FocusNode originFocusNode;
  final FocusNode destFocusNode;

  /// false = el mapa no fija origen/destino con el pin central (A/B): muestra
  /// los marcadores y la ruta, y arrastrarlo no cambia el viaje.
  final bool allowPinSelection;

  /// Zonas tapadas por otros elementos (cabecera, panel inferior) mientras
  /// se muestra la ruta ([allowPinSelection] en false): el encuadre de origen
  /// y destino se hace en la parte que queda a la vista. Con el pin activo
  /// no se aplica, para que el pin siga marcando el centro del mapa.
  final EdgeInsets routePadding;

  /// Con [allowPinSelection]: true = el pin central marca el destino (rojo)
  /// en vez del origen; al soltar el mapa se fija el nuevo destino.
  final bool editDestination;

  @override
  State<ClientMapLayer> createState() => _ClientMapLayerState();
}

class _RouteProgressSampler {
  _RouteProgressSampler(List<LatLng> points) : _points = points {
    _cumulativeKm = List<double>.filled(points.length, 0);
    for (var i = 1; i < points.length; i++) {
      _cumulativeKm[i] =
          _cumulativeKm[i - 1] + LocationHelper.calculateDistance(
            points[i - 1],
            points[i],
          );
    }
    _totalKm = points.length > 1 ? _cumulativeKm.last : 0;
  }

  final List<LatLng> _points;
  late final List<double> _cumulativeKm;
  late final double _totalKm;

  List<LatLng> sample(double progress) {
    if (_points.length < 2) return List<LatLng>.from(_points);
    final t = progress.clamp(0.0, 1.0);
    if (t >= 1.0) return List<LatLng>.from(_points);
    if (t <= 0) return [_points.first, _points.first];

    final targetKm = _totalKm * t;
    var segmentIndex = 1;
    while (segmentIndex < _cumulativeKm.length &&
        _cumulativeKm[segmentIndex] < targetKm) {
      segmentIndex++;
    }
    if (segmentIndex >= _points.length) {
      return List<LatLng>.from(_points);
    }

    final segStartKm = _cumulativeKm[segmentIndex - 1];
    final segEndKm = _cumulativeKm[segmentIndex];
    final segLen = segEndKm - segStartKm;
    final frac = segLen > 0 ? (targetKm - segStartKm) / segLen : 0.0;

    final a = _points[segmentIndex - 1];
    final b = _points[segmentIndex];
    final head = LatLng(
      a.latitude + (b.latitude - a.latitude) * frac,
      a.longitude + (b.longitude - a.longitude) * frac,
    );

    final partial = List<LatLng>.from(_points.sublist(0, segmentIndex));
    partial.add(head);
    return partial.length >= 2 ? partial : [head, head];
  }
}

class _ClientMapLayerState extends State<ClientMapLayer>
    with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  String? _mapError;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destIcon;
  Offset _originMarkerAnchor = const Offset(0.5, 0.5);
  Offset _destMarkerAnchor = const Offset(0.5, 1.0);
  String? _destIconLabelKey;
  String? _originIconLabelKey;
  AnimationController? _routeDrawController;

  StreamSubscription<Position>? _userPositionSub;
  LatLng? _userLocationLatLng;
  BitmapDescriptor? _myLocationDotIcon;

  Timer? _mapInactivityTimer;
bool _mapAutoFollowEnabled = true;
  int _programmaticCameraMoveCount = 0;
  LatLng? _pickupPreviewLatLng;
  bool _isPickupMapMoving = false;
  bool _didInitialPickupAutoZoom = false;
  LatLng? _cameraMoveStartLatLng;

  String? _debugLastRideSig;
  bool _wasSearchingDriver = false;
  double _searchZoomLevel = AppConstants.defaultZoom + 1.8;

  // Smooth zoom-out animation state
  Timer? _searchSmoothTimer;
  bool _searchZoomMovePending = false; // true while our moveCamera call is in flight
  int _searchElapsedMs = 0;           // accumulated ms of animation time
  int? _searchLastMs;                  // null = paused, non-null = last tick timestamp
  double _searchCircleRadius = 300;
  Set<Circle> _searchCircles = {};

  int _routePreviewAnimToken = 0;
  bool _isAnimatingRoutePreview = false;
  String? _lastAnimatedRoutePreviewKey;
  String? _lastAutoFittedRouteKey;
  ClientRideStatus? _trackedRideStatus;
  bool _showRecenterRouteButton = false;
  bool _mapExploreLock = false;
  int _lastMapUserActivityMs = 0;
  int _lastPickupPreviewUpdateMs = 0;
  String? _lastOverlaySignature;
  String? _centerPinStreetLabel;
  Timer? _reverseGeocodeDebounce;
  int _reverseGeocodeToken = 0;
  Offset? _searchPulseScreenOffset;
  int _lastPulsePositionUpdateMs = 0;
  /// Pin B activo tras abrir destino; persiste aunque el teclado se oculte al tocar el mapa.
  bool _destMapPinActive = false;

  void _debugLog(String message, {int level = 800}) {
    if (!kDebugMode) return;
    log(message, name: 'LlevaClientDashboard', level: level);
  }

  bool _useNativeMyLocation(ClientRideState state) {
    if (state.activeRide != null) return true;
    if (state.originLatLng == null || state.destLatLng == null) return true;
    if (_isMapPinSelectionEnabled(state)) return true;
    return false;
  }

  void _syncUserLocationStream(ClientRideState state) {
    if (_useNativeMyLocation(state)) {
      _userPositionSub?.cancel();
      _userPositionSub = null;
      if (_userLocationLatLng != null) {
        _userLocationLatLng = null;
        if (mounted) {
          _updateMapOverlays(context.read<ClientRideBloc>().state);
        }
      }
      return;
    }
    if (_userPositionSub != null) return;

    void applyPosition(Position p) {
      if (!mounted) return;
      _userLocationLatLng = LatLng(p.latitude, p.longitude);
      _updateMapOverlays(context.read<ClientRideBloc>().state);
    }

    _userPositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(applyPosition, onError: (_) {});

    unawaited(
      LocationHelper.determinePosition()
          .then(applyPosition)
          .catchError((_) {}),
    );
  }

  bool get _isProgrammaticCameraMove => _programmaticCameraMoveCount > 0;

  /// Ajuste de recojo en mapa (por defecto o sin modo destino activo).
  bool _isOriginMapSelectionEnabled(ClientRideState state) {
    return widget.allowPinSelection &&
        state.activeRide == null &&
        state.status == ClientRideStatus.initial &&
        !_destMapPinActive &&
        !widget.editDestination;
  }

  /// Destino en mapa: activo hasta pulsar «Pedir Lleva» (aunque ya haya coordenadas).
  bool _isDestMapSelectionEnabled(ClientRideState state) {
    return widget.allowPinSelection &&
        state.activeRide == null &&
        state.status == ClientRideStatus.initial &&
        state.originLatLng != null &&
        (_destMapPinActive || widget.editDestination);
  }

  void _dismissSearchKeyboard() {
    if (!mounted) return;
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && primary.hasFocus) {
      primary.unfocus();
    }
  }

  bool _isMapPinSelectionEnabled(ClientRideState state) {
    return _isOriginMapSelectionEnabled(state) ||
        _isDestMapSelectionEnabled(state);
  }

  bool _isSearchingRideState(ClientRideState state) {
    return state.status == ClientRideStatus.searchingDriver ||
        state.status == ClientRideStatus.requesting;
  }

  /// Vista por defecto al buscar conductor: pulso en origen, sin A/B ni ruta.
  bool _isSearchIdleMapView(ClientRideState state) {
    return _isSearchingRideState(state) && _mapAutoFollowEnabled;
  }

  void _onMapFocusChanged() {
    if (!mounted) return;
    final state = context.read<ClientRideBloc>().state;
    if (widget.destFocusNode.hasFocus && state.originLatLng != null) {
      _destMapPinActive = true;
      _centerPinStreetLabel = null;
      _pickupPreviewLatLng = state.destLatLng ?? state.originLatLng;
      _scheduleCenterPinReverseGeocode(_pickupPreviewLatLng!);
      // Centra la cámara en la posición actual del destino al activar el modo
      // pin de destino, para que el pin central coincida con la coordenada real.
      if (_mapController != null && _pickupPreviewLatLng != null) {
        unawaited(
          _animateMapCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _pickupPreviewLatLng!,
                zoom: AppConstants.defaultZoom + 3.8,
              ),
            ),
          ),
        );
      }
    } else if (widget.originFocusNode.hasFocus) {
      _destMapPinActive = false;
      if (state.originLatLng != null) {
        _pickupPreviewLatLng = state.originLatLng;
        _applyOriginNameToCenterLabel(state);
      }
    }
    setState(() {});
    _updateMapOverlays(state);
  }

  Future<void> _refreshSearchPulseScreenPosition(LatLng origin) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    try {
      final screenCoord = await controller.getScreenCoordinate(origin);
      if (!mounted) return;
      setState(() {
        _searchPulseScreenOffset = Offset(
          screenCoord.x.toDouble(),
          screenCoord.y.toDouble(),
        );
      });
    } catch (_) {}
  }

  void _onMapCameraMoveForSearchPulse(ClientRideState state) {
    if (!_isSearchIdleMapView(state) || state.originLatLng == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastPulsePositionUpdateMs < 50) return;
    _lastPulsePositionUpdateMs = nowMs;
    unawaited(_refreshSearchPulseScreenPosition(state.originLatLng!));
  }

  String _centerPinLabelForState(ClientRideState state) {
    if (_centerPinStreetLabel != null && _centerPinStreetLabel!.trim().isNotEmpty) {
      return _centerPinStreetLabel!;
    }
    if (_isDestMapSelectionEnabled(state)) {
      final fromDest = CustomMapMarkers.streetLabelFromAddress(state.destName);
      if (fromDest != 'Buscando…') return fromDest;
    }
    if (_isOriginMapSelectionEnabled(state)) {
      final fromOrigin = CustomMapMarkers.streetLabelFromAddress(state.originName);
      if (fromOrigin != 'Buscando…') return fromOrigin;
    }
    return CenterPinPainter.loadingLabel;
  }

  /// Busca la calle bajo el pin central. Mientras tanto el pin muestra los
  /// puntos de carga; si Google no devuelve dirección, «Aquí» (antes quedaba
  /// «Buscando…» para siempre).
  void _scheduleCenterPinReverseGeocode(LatLng target) {
    _reverseGeocodeDebounce?.cancel();
    if (_centerPinStreetLabel != CenterPinPainter.loadingLabel && mounted) {
      setState(() => _centerPinStreetLabel = CenterPinPainter.loadingLabel);
    }
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 350), () async {
      final token = ++_reverseGeocodeToken;
      String? address;
      try {
        address = await di.sl<PlacesService>().reverseGeocode(target);
      } catch (_) {
        address = null;
      }
      if (!mounted || token != _reverseGeocodeToken) return;
      setState(() {
        _centerPinStreetLabel = address == null
            ? 'Aquí'
            : CustomMapMarkers.streetLabelFromAddress(address);
      });
    });
  }

  bool _latLngAlmostEqual(
    LatLng a,
    LatLng b, {
    double epsilon = 0.00001,
  }) {
    return (a.latitude - b.latitude).abs() < epsilon &&
        (a.longitude - b.longitude).abs() < epsilon;
  }

  double _approxDistanceMeters(LatLng a, LatLng b) {
    const metersPerDegLat = 111320.0;
    final avgLatRad = ((a.latitude + b.latitude) / 2) * (3.1415926535 / 180.0);
    final metersPerDegLng = metersPerDegLat * math.cos(avgLatRad);
    final dx = (a.longitude - b.longitude) * metersPerDegLng;
    final dy = (a.latitude - b.latitude) * metersPerDegLat;
    return math.sqrt((dx * dx) + (dy * dy));
  }

  void _onMapCameraMoveStarted() {
    // Our smooth search-zoom calls moveCamera: ignore those callbacks.
    if (_searchZoomMovePending) return;
    if (_isProgrammaticCameraMove) return;
    final state = context.read<ClientRideBloc>().state;
    if (_isMapPinSelectionEnabled(state)) {
      _dismissSearchKeyboard();
      // Borra el trazo anterior en cuanto el usuario empieza a arrastrar el pin,
      // para que la ruta no se mantenga visible mientras se reposiciona.
      if (_polylines.isNotEmpty || _isAnimatingRoutePreview) {
        _cancelRoutePreviewAnimation();
        _lastAnimatedRoutePreviewKey = null;
        setState(() {
          _polylines = {};
        });
      }
    }
    _debugLog(
      '[MAP_GESTURE] onCameraMoveStarted manual '
      'status=${state.status} '
      'autoFollow=$_mapAutoFollowEnabled '
      'progMoves=$_programmaticCameraMoveCount',
    );
    if (!widget.mapGestureActiveNotifier.value) {
      widget.mapGestureActiveNotifier.value = true;
    }
    if (_isFinalRouteOverviewState(state) && !_showRecenterRouteButton) {
      setState(() {
        _showRecenterRouteButton = true;
      });
    }
    _mapInactivityTimer?.cancel();
    if (_isMapPinSelectionEnabled(state)) {
      _cameraMoveStartLatLng = _pickupPreviewLatLng ??
          (_isDestMapSelectionEnabled(state)
              ? state.destLatLng
              : state.originLatLng);
    }
    if (_mapAutoFollowEnabled) {
      final isSearching = _isSearchingRideState(state);
      setState(() {
        _mapAutoFollowEnabled = false;
        _searchPulseScreenOffset = null;
        // Hide the expanding-circle overlay while user explores the map.
        if (isSearching) _searchCircles = {};
      });
      if (isSearching) {
        _updateMapOverlays(state);
        if (state.originLatLng != null && state.destLatLng != null) {
          unawaited(
            _fitRouteOverview(state.originLatLng!, state.destLatLng!),
          );
        }
      }
    }
  }

  void _onMapUserActivity() {
    if (_isProgrammaticCameraMove) return;
    _mapInactivityTimer?.cancel();
    final currentState = context.read<ClientRideBloc>().state;
    final isFinalRouteOverview = _isFinalRouteOverviewState(currentState);
    _mapInactivityTimer = Timer(
      Duration(seconds: isFinalRouteOverview ? 15 : 5),
      () {
      if (!mounted) return;
      final stateAtTimeout = context.read<ClientRideBloc>().state;
      _debugLog(
        '[MAP_GESTURE] inactivity timeout fired '
        'status=${stateAtTimeout.status} '
        'hasOrigin=${stateAtTimeout.originLatLng != null} '
        'hasDest=${stateAtTimeout.destLatLng != null}',
      );
      if (_isMapPinSelectionEnabled(stateAtTimeout)) {
        _debugLog('[MAP_GESTURE] inactivity ignored: map pin selection active');
        return;
      }
      if (stateAtTimeout.originLatLng != null &&
          stateAtTimeout.destLatLng != null) {
        _debugLog('[MAP_GESTURE] inactivity ignored: route already fixed');
        return;
      }
      if (_isFinalRouteOverviewState(stateAtTimeout)) {
        // En ruta final no forzamos recenter automático:
        // el usuario mantiene control total del mapa.
        _debugLog('[MAP_GESTURE] inactivity ignored: final route overview');
        return;
      }
      setState(() {
        _mapAutoFollowEnabled = true;
      });
      _debugLog('[MAP_GESTURE] inactivity re-enables autoFollow=true');
      _updateMapOverlays(stateAtTimeout);
    },
    );
  }

  void _onMapCameraMove(CameraPosition position, ClientRideState state) {
    if (_isProgrammaticCameraMove) return;
    final mapPinSelectionEnabled = _isMapPinSelectionEnabled(state);
    if (!mapPinSelectionEnabled) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastMapUserActivityMs >= 120) {
      _lastMapUserActivityMs = nowMs;
      _onMapUserActivity();
    }

    final target = position.target;
    if (_pickupPreviewLatLng != null &&
        _latLngAlmostEqual(_pickupPreviewLatLng!, target)) {
      return;
    }
    if (nowMs - _lastPickupPreviewUpdateMs < 50) {
      return;
    }
    _lastPickupPreviewUpdateMs = nowMs;

    setState(() {
      _pickupPreviewLatLng = target;
      _isPickupMapMoving = true;
    });
    _scheduleCenterPinReverseGeocode(target);
  }

  void _onMapCameraIdle(ClientRideState state) {
    _onMapUserActivity();
    _debugLog(
      '[MAP_GESTURE] onCameraIdle '
      'status=${state.status} '
      'autoFollow=$_mapAutoFollowEnabled '
      'progMoves=$_programmaticCameraMoveCount',
    );
    if (!_mapExploreLock && widget.mapGestureActiveNotifier.value) {
      widget.mapGestureActiveNotifier.value = false;
    }
    if (_isPickupMapMoving) {
      setState(() {
        _isPickupMapMoving = false;
      });
    }
    if (_isProgrammaticCameraMove) return;
    if (!_isMapPinSelectionEnabled(state)) return;
    if (_cameraMoveStartLatLng == null) return;

    final target = _pickupPreviewLatLng;
    if (target == null) return;

    final isDestMode = _isDestMapSelectionEnabled(state);
    final confirmed = isDestMode ? state.destLatLng : state.originLatLng;
    if (confirmed != null && _latLngAlmostEqual(confirmed, target)) {
      return;
    }

    final moveStart = _cameraMoveStartLatLng ?? confirmed;
    if (moveStart != null) {
      final movedMeters = _approxDistanceMeters(moveStart, target);
      if (movedMeters < 12) {
        if (confirmed != null) {
          setState(() {
            _pickupPreviewLatLng = confirmed;
          });
        }
        _cameraMoveStartLatLng = null;
        return;
      }
    }

    _cameraMoveStartLatLng = null;
    final rideBloc = context.read<ClientRideBloc>();
    if (isDestMode) {
      rideBloc.add(DestPinMoved(target));
    } else {
      rideBloc.add(PickupPinMoved(target));
    }
  }

  Future<void> _animateMapCamera(CameraUpdate update) async {
    if (_mapController == null) return;
    _debugLog(
      '[MAP_CAMERA] animateCamera start '
      'autoFollow=$_mapAutoFollowEnabled '
      'progMoves=$_programmaticCameraMoveCount',
    );
    _programmaticCameraMoveCount++;
    try {
      await _mapController!.animateCamera(update);
    } catch (_) {
      // Ignora errores transitorios de plataforma al animar cámara.
    } finally {
      _debugLog('[MAP_CAMERA] animateCamera end progMoves=$_programmaticCameraMoveCount');
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_programmaticCameraMoveCount > 0) {
          _programmaticCameraMoveCount--;
        }
      });
    }
  }

  Future<void> _loadClientMapIcons(BuildContext context) async {
    BitmapDescriptor? car;
    BitmapDescriptor? origin;
    BitmapDescriptor? dest;
    BitmapDescriptor? myDot;
    try {
      // Mismo pin «gota» azul que el pin central de la pestaña Mapa.
      origin = await CustomMapMarkers.createPinMarker();
    } catch (_) {}
    try {
      dest = await CustomMapMarkers.createPinMarker(
        color: CustomMapMarkers.destPinColor,
      );
    } catch (_) {}
    try {
      car = await CustomMapMarkers.createCarMarker();
    } catch (_) {}
    try {
      myDot = await CustomMapMarkers.createMyLocationDotMarker();
    } catch (_) {}
    if (!context.mounted) return;
    setState(() {
      _carIcon = car;
      _originIcon = origin;
      _originMarkerAnchor = const Offset(0.5, 1.0);
      if (origin != null) _originIconLabelKey = _kOriginPinIconKey;
      _destIcon = dest;
      _destMarkerAnchor = const Offset(0.5, 1.0);
      if (dest != null) _destIconLabelKey = _kDestPinIconKey;
      _myLocationDotIcon = myDot;
    });
    final rideBloc = context.read<ClientRideBloc>();
    _updateMapOverlays(rideBloc.state);
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await _setMapStyle();
    _debugLog('GoogleMap onMapCreated: controlador asignado');
    final rideState = context.read<ClientRideBloc>().state;
    if (rideState.originLatLng == null) {
      context
          .read<ClientRideBloc>()
          .add(const InitializePickupFromCurrentLocation());
    }
    setState(() {
      _mapError = null;
    });
    if (rideState.originLatLng != null) {
      _scheduleCenterPinReverseGeocode(rideState.originLatLng!);
    }
    // El mapa puede montarse con el origen ya resuelto (el dashboard lo
    // muestra recién al buscar): sin un cambio de estado posterior nadie
    // centraría la cámara, así que se sincroniza aquí.
    _updateMapOverlays(rideState);
  }

  void _handleSearchingCameraBehavior(ClientRideState state) {
    final isSearching = state.status == ClientRideStatus.searchingDriver;
    if (isSearching && !_wasSearchingDriver) {
      _wasSearchingDriver = true;
      _stopSearchSmoothZoom(); // clean up any previous run
      _searchElapsedMs = 0;
      _searchZoomLevel = AppConstants.defaultZoom + 1.8;
      _searchCircleRadius = 300;
      _mapAutoFollowEnabled = true;
      _searchPulseScreenOffset = null;

      final origin = state.originLatLng;
      if (origin != null) {
        unawaited(_refreshSearchPulseScreenPosition(origin));
        // Snap camera to starting zoom and draw initial circle.
        _searchMoveCamera(origin, _searchZoomLevel);
        setState(() {
          _searchCircles = _buildSearchCircles(origin, _searchCircleRadius);
        });
      }

      // Smooth zoom-out: 200 ms ticks — tiny steps look fluid.
      _searchSmoothTimer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          if (!mounted) {
            _stopSearchSmoothZoom();
            return;
          }
          final cur = context.read<ClientRideBloc>().state;
          if (cur.status != ClientRideStatus.searchingDriver) {
            _stopSearchSmoothZoom();
            return;
          }

          if (!_mapAutoFollowEnabled) {
            // User is interacting → pause time tracking.
            _searchLastMs = null;
            return;
          }

          final nowMs = DateTime.now().millisecondsSinceEpoch;
          final lastMs = _searchLastMs;
          if (lastMs == null) {
            // Resuming after user released the map.
            _searchLastMs = nowMs;
            final o = cur.originLatLng;
            if (o != null) {
              _searchMoveCamera(o, _searchZoomLevel);
              setState(() {
                _searchCircles = _buildSearchCircles(o, _searchCircleRadius);
              });
            }
            return;
          }

          final dt = (nowMs - lastMs).clamp(0, 500);
          _searchLastMs = nowMs;
          _searchElapsedMs = (_searchElapsedMs + dt).clamp(0, 25000);

          final newZoom = _searchZoomForElapsed(_searchElapsedMs);
          final newRadius = _searchRadiusForElapsed(_searchElapsedMs);
          final zoomChanged = (newZoom - _searchZoomLevel).abs() > 0.003;
          final radiusChanged = (newRadius - _searchCircleRadius).abs() > 20;

          if (zoomChanged || radiusChanged) {
            _searchZoomLevel = newZoom;
            _searchCircleRadius = newRadius;
            final o = cur.originLatLng;
            if (o != null) {
              if (zoomChanged) _searchMoveCamera(o, newZoom);
              if (radiusChanged) {
                setState(() {
                  _searchCircles = _buildSearchCircles(o, newRadius);
                });
              }
            }
          }
        },
      );
      return;
    }

    if (!isSearching && _wasSearchingDriver) {
      _wasSearchingDriver = false;
      _stopSearchSmoothZoom();
    }
  }

  // ──────────────────────────────────────────────
  // Smooth search-zoom animation helpers
  // ──────────────────────────────────────────────

  /// Zoom at time [elapsedMs] within the 25-second animation.
  /// Goes from defaultZoom+1.8 → defaultZoom (≈5 km radius) with ease-out.
  double _searchZoomForElapsed(int elapsedMs) {
    const totalMs = 25000;
    final t = (elapsedMs / totalMs).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    const zStart = AppConstants.defaultZoom + 1.8;
    const zEnd = AppConstants.defaultZoom;
    return zStart + (zEnd - zStart) * eased;
  }

  /// Circle radius (meters) that grows proportionally with the zoom-out.
  double _searchRadiusForElapsed(int elapsedMs) {
    const totalMs = 25000;
    final t = (elapsedMs / totalMs).clamp(0.0, 1.0);
    return 300 + 4700 * t; // 300 m → 5 000 m
  }

  Set<Circle> _buildSearchCircles(LatLng center, double radius) {
    return {
      Circle(
        circleId: const CircleId('search_radius'),
        center: center,
        radius: radius,
        fillColor: AppTheme.primaryBlue.withValues(alpha: 0.06),
        strokeColor: AppTheme.primaryBlue.withValues(alpha: 0.35),
        strokeWidth: 1,
        zIndex: 0,
      ),
      Circle(
        circleId: const CircleId('search_radius_inner'),
        center: center,
        radius: radius * 0.5,
        fillColor: Colors.transparent,
        strokeColor: AppTheme.primaryBlue.withValues(alpha: 0.20),
        strokeWidth: 1,
        zIndex: 0,
      ),
    };
  }

  /// Instant camera move for the search animation (no built-in animation).
  /// Sets [_searchZoomMovePending] so [_onMapCameraMoveStarted] ignores the callback.
  void _searchMoveCamera(LatLng origin, double zoom) {
    if (!mounted || _mapController == null) return;
    _searchZoomMovePending = true;
    _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: origin, zoom: zoom),
      ),
    );
    // Clear the guard after the platform fires onCameraMoveStarted (≈1 frame).
    Future.delayed(const Duration(milliseconds: 80), () {
      _searchZoomMovePending = false;
    });
  }

  void _stopSearchSmoothZoom() {
    _searchSmoothTimer?.cancel();
    _searchSmoothTimer = null;
    _searchLastMs = null;
    if (mounted && _searchCircles.isNotEmpty) {
      setState(() {
        _searchCircles = {};
      });
    }
  }

  Future<void> _setMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/map_style.json');
      await _mapController?.setMapStyle(style);
    } catch (error) {
      _debugLog('No se pudo aplicar el estilo del mapa: $error', level: 900);
    }
  }

  bool _shouldAnimateRoutePreview(ClientRideState state) {
    // No animar mientras el usuario esté posicionando el pin de destino:
    // la animación mueve la cámara al overview de la ruta y hace que el
    // pin central parezca desplazarse de donde el usuario lo colocó.
    // En ese modo el trazo se dibuja de forma estática sin mover la cámara.
    return state.activeRide == null &&
        state.originLatLng != null &&
        state.destLatLng != null &&
        state.routePolyline.length > 1 &&
        !_isPickupMapMoving &&
        !_isDestMapSelectionEnabled(state) &&
        state.status != ClientRideStatus.searchingDriver &&
        state.status != ClientRideStatus.requesting;
  }

  bool _isFinalRouteOverviewState(ClientRideState state) {
    return state.activeRide == null &&
        state.originLatLng != null &&
        state.destLatLng != null &&
        state.routePolyline.length > 1;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  Future<void> _fitRouteOverview(
    LatLng origin,
    LatLng destination, {
    List<LatLng>? routePoints,
    double padding = 140,
    bool animated = false,
  }) async {
    if (_mapController == null) return;
    final bounds = routePoints != null && routePoints.length >= 2
        ? _boundsFromLatLngList(routePoints)
        : _boundsFromLatLngs(origin, destination);
    _programmaticCameraMoveCount++;
    try {
      final update = CameraUpdate.newLatLngBounds(bounds, padding);
      if (animated) {
        await _mapController!.animateCamera(update);
      } else {
        await _mapController!.moveCamera(update);
      }
    } catch (_) {
      // Ignora errores transitorios de plataforma al mover cámara.
    } finally {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_programmaticCameraMoveCount > 0) {
          _programmaticCameraMoveCount--;
        }
      });
    }
  }

  Future<void> _fitRouteOverviewForState(
    ClientRideState state, {
    bool animated = true,
  }) async {
    final origin = state.originLatLng;
    final dest = state.destLatLng;
    if (origin == null || dest == null) return;
    await _fitRouteOverview(
      origin,
      dest,
      routePoints: state.routePolyline.length >= 2
          ? state.routePolyline
          : null,
      padding: _routeFitPadding,
      animated: animated,
    );
    _lastAutoFittedRouteKey = _autoFitRouteKey(state);
  }

  String _autoFitRouteKey(ClientRideState state) {
    return '${state.originLatLng}|${state.destLatLng}|${state.routePolyline.length}';
  }

  String _routePreviewKey(ClientRideState state) {
    final first = state.routePolyline.first;
    final last = state.routePolyline.last;
    return '${state.originLatLng}|${state.destLatLng}|${state.routePolyline.length}|'
        '${first.latitude},${first.longitude}|${last.latitude},${last.longitude}';
  }

  void _cancelRoutePreviewAnimation() {
    _routePreviewAnimToken++;
    _routeDrawController?.stop();
    _routeDrawController?.dispose();
    _routeDrawController = null;
    _isAnimatingRoutePreview = false;
  }

  Future<void> _animateRoutePreview({
    required Set<Marker> markers,
    required List<LatLng> routePoints,
    required LatLng origin,
    required LatLng destination,
    required String routeKey,
  }) async {
    if (_mapController == null || routePoints.length < 2) return;

    _cancelRoutePreviewAnimation();
    final animToken = _routePreviewAnimToken;
    _isAnimatingRoutePreview = true;
    _lastAnimatedRoutePreviewKey = routeKey;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _routeDrawController = controller;

    final sampler = _RouteProgressSampler(routePoints);
    // Ruta completa (no solo los extremos): el trazo puede salirse de ellos.
    final bounds =
        _boundsFromLatLngList([origin, destination, ...routePoints]);

    if (mounted) {
      setState(() {
        _markers = markers;
        _polylines = {};
      });
    }

    await _animateMapCamera(
      CameraUpdate.newLatLngBounds(bounds, _routeFitPadding),
    );
    // Primero se ven solo los dos pines; pasado [_kRouteRevealDelay] se
    // dibuja la ruta de origen a destino.
    if (mounted && animToken == _routePreviewAnimToken) {
      await Future<void>.delayed(_kRouteRevealDelay);
    }
    if (!mounted || animToken != _routePreviewAnimToken) {
      if (_routeDrawController == controller) {
        controller.dispose();
        _routeDrawController = null;
      }
      _isAnimatingRoutePreview = false;
      return;
    }

    // Se redibuja en cada cuadro: el sampler interpola la punta dentro del
    // tramo, así que avanza suave aunque la ruta tenga pocos puntos (antes
    // solo se actualizaba al cambiar de tramo y avanzaba a saltos).
    void onRouteTick() {
      if (!mounted || animToken != _routePreviewAnimToken) return;
      final eased = Curves.easeInOutCubic.transform(controller.value);
      final partial = sampler.sample(eased);
      setState(() => _polylines = _routePolylines(partial));
    }

    controller.addListener(onRouteTick);
    try {
      await controller.forward();
    } finally {
      controller.removeListener(onRouteTick);
      if (_routeDrawController == controller) {
        controller.dispose();
        _routeDrawController = null;
      }
    }

    if (!mounted || animToken != _routePreviewAnimToken) {
      _isAnimatingRoutePreview = false;
      return;
    }
    _isAnimatingRoutePreview = false;
    setState(() {
      _markers = markers;
      _polylines = _routePolylines(routePoints);
    });
  }

  /// Ruta del viaje: un halo ancho y translúcido debajo (da relieve) y la
  /// línea azul sólida encima, con extremos y uniones redondeados.
  Set<Polyline> _routePolylines(List<LatLng> points) {
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

  bool _shouldShowRouteSummary(ClientRideState state) {
    return state.activeRide != null;
  }

  /// El marcador de origen es siempre el pin «gota» azul (sin etiqueta: la
  /// calle va en el panel inferior y en el globo del marcador). Solo se
  /// genera una vez.
  Future<void> _syncOriginMarkerIcon(ClientRideState state) async {
    if (_originIconLabelKey == _kOriginPinIconKey && _originIcon != null) {
      return;
    }
    try {
      final icon = await CustomMapMarkers.createPinMarker();
      if (!mounted) return;
      setState(() {
        _originIcon = icon;
        _originMarkerAnchor = const Offset(0.5, 1.0);
        _originIconLabelKey = _kOriginPinIconKey;
      });
    } catch (_) {}
  }

  /// El marcador de destino es el pin «gota» rojo, pareja del azul de
  /// origen (la distancia y el tiempo van en el panel inferior). Solo se
  /// genera una vez.
  Future<void> _syncDestMarkerIcon(ClientRideState state) async {
    if (_destIconLabelKey == _kDestPinIconKey && _destIcon != null) return;
    try {
      final icon = await CustomMapMarkers.createPinMarker(
        color: CustomMapMarkers.destPinColor,
      );
      if (!mounted) return;
      setState(() {
        _destIcon = icon;
        _destMarkerAnchor = const Offset(0.5, 1.0);
        _destIconLabelKey = _kDestPinIconKey;
      });
    } catch (_) {}
  }

  void _updateMapOverlays(ClientRideState state) {
    if (state.originLatLng == null || state.destLatLng == null) {
      _lastAutoFittedRouteKey = null;
      if (_showRecenterRouteButton) {
        _showRecenterRouteButton = false;
      }
    }
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (!_useNativeMyLocation(state) &&
        _userLocationLatLng != null &&
        _myLocationDotIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _userLocationLatLng!,
          icon: _myLocationDotIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
        ),
      );
    }

    final mapPinSelectionEnabled = _isMapPinSelectionEnabled(state);
    if (!mapPinSelectionEnabled) {
      _pickupPreviewLatLng = null;
      _isPickupMapMoving = false;
      _cameraMoveStartLatLng = null;
      _centerPinStreetLabel = null;
    }
    // Punto ya confirmado que marca el pin central: el destino al editarlo,
    // si no, el origen.
    final pinAnchor = _isDestMapSelectionEnabled(state)
        ? (state.destLatLng ?? state.originLatLng)
        : state.originLatLng;
    if (state.originLatLng == null) {
      _didInitialPickupAutoZoom = false;
    } else if (pinAnchor != null &&
        (_pickupPreviewLatLng == null ||
            (!_isPickupMapMoving &&
                !_latLngAlmostEqual(_pickupPreviewLatLng!, pinAnchor)))) {
      // Mantiene el pin centrado sincronizado con el punto real
      // (ubicación actual al inicio o cambios confirmados en el bloc).
      _pickupPreviewLatLng = pinAnchor;
    }

    final searchIdleView = _isSearchIdleMapView(state);

    // El pin que no se está editando sigue a la vista.
    if (state.originLatLng != null &&
        !_isOriginMapSelectionEnabled(state) &&
        !searchIdleView) {
      final originMarkerPosition = state.originLatLng!;
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: originMarkerPosition,
          draggable: false,
          onDragEnd: null,
          anchor: _originIcon != null
              ? _originMarkerAnchor
              : const Offset(0.5, 1.0),
          icon: _originIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
          infoWindow: InfoWindow(
            title: (state.originName?.trim().isNotEmpty ?? false)
                ? state.originName!.split('\n').first.trim()
                : 'Origen',
          ),
          zIndexInt: 1002,
        ),
      );
    }

    if (state.destLatLng != null &&
        !searchIdleView &&
        !_isDestMapSelectionEnabled(state)) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest'),
          position: state.destLatLng!,
          anchor: _destIcon != null
              ? _destMarkerAnchor
              : const Offset(0.5, 1.0),
          icon: _destIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
          zIndexInt: 1003,
        ),
      );
    }

    final activeRide = state.activeRide;
    if (activeRide != null &&
        activeRide.driverLat != null &&
        activeRide.driverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_vehicle'),
          position: LatLng(activeRide.driverLat!, activeRide.driverLng!),
          anchor: _carIcon != null
              ? const Offset(0.5, 0.5)
              : const Offset(0.5, 1.0),
          icon: _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
          zIndexInt: 1004,
          infoWindow: const InfoWindow(
            title: 'Conductor',
          ),
        ),
      );
    }

    final shouldHideRouteWhileSearching = searchIdleView;
    final shouldAnimatePreview = _shouldAnimateRoutePreview(state);
    if (state.routePolyline.isNotEmpty && !shouldHideRouteWhileSearching) {
      if (shouldAnimatePreview) {
        final key = _routePreviewKey(state);
        if (_lastAnimatedRoutePreviewKey != key && !_isAnimatingRoutePreview) {
          unawaited(
            _animateRoutePreview(
              markers: markers,
              routePoints: state.routePolyline,
              origin: state.originLatLng!,
              destination: state.destLatLng!,
              routeKey: key,
            ).whenComplete(() {
              if (!mounted) return;
              _isAnimatingRoutePreview = false;
            }),
          );
        } else if (_lastAnimatedRoutePreviewKey == key &&
            !_isAnimatingRoutePreview) {
          polylines.addAll(_routePolylines(state.routePolyline));
        }
      } else {
        if (_isAnimatingRoutePreview) {
          _cancelRoutePreviewAnimation();
        }
        _lastAnimatedRoutePreviewKey = null;
        polylines.addAll(_routePolylines(state.routePolyline));
      }
    } else {
      if (_isAnimatingRoutePreview) {
        _cancelRoutePreviewAnimation();
      }
      _lastAnimatedRoutePreviewKey = null;
    }

    final overlaySignature = _buildOverlaySignature(
      state: state,
      markers: markers,
      polylines: polylines,
    );
    if (_lastOverlaySignature != overlaySignature) {
      _lastOverlaySignature = overlaySignature;
      scheduleMicrotask(() {
        if (!mounted) return;
        setState(() {
          _markers = markers;
          _polylines = polylines;
        });
      });
    }
    unawaited(_syncOriginMarkerIcon(state));
    unawaited(_syncDestMarkerIcon(state));

    if (_mapController != null && _mapAutoFollowEnabled) {
      if (_isAnimatingRoutePreview) {
        _debugLog('[MAP_AUTOFOLLOW] skip: animating route preview');
        return;
      }
      if (mapPinSelectionEnabled && state.originLatLng != null) {
        if (!_didInitialPickupAutoZoom) {
          _didInitialPickupAutoZoom = true;
          _debugLog('[MAP_AUTOFOLLOW] initial pickup autozoom');
          // Editando el destino, la cámara va al destino actual: así el pin
          // central arranca sobre él.
          final target = _isDestMapSelectionEnabled(state)
              ? (state.destLatLng ?? state.originLatLng!)
              : state.originLatLng!;
          _animateMapCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: target,
                zoom: AppConstants.defaultZoom + 3.8,
              ),
            ),
          );
        }
        return;
      }

      final ride = state.activeRide;
      if ((state.status == ClientRideStatus.driverAssigned ||
              state.status == ClientRideStatus.driverArrived) &&
          state.originLatLng != null &&
          ride != null &&
          ride.driverLat != null &&
          ride.driverLng != null) {
        _debugLog('[MAP_AUTOFOLLOW] fitting driver-origin bounds');
        final driverPos = LatLng(ride.driverLat!, ride.driverLng!);
        final bounds = _boundsFromLatLngs(state.originLatLng!, driverPos);
        _animateMapCamera(
          CameraUpdate.newLatLngBounds(bounds, 160),
        );
      } else if (state.originLatLng != null &&
          state.destLatLng == null &&
          state.activeRide == null) {
        _debugLog('[MAP_AUTOFOLLOW] centering on origin without destination');
        _animateMapCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: state.originLatLng!,
              zoom: AppConstants.defaultZoom + 0.8,
            ),
          ),
        );
      } else if (state.originLatLng != null && state.destLatLng != null) {
        final routeKey = _autoFitRouteKey(state);
        if (_lastAutoFittedRouteKey != routeKey) {
          _lastAutoFittedRouteKey = routeKey;
          if (_showRecenterRouteButton) {
            _showRecenterRouteButton = false;
          }
          _debugLog('[MAP_AUTOFOLLOW] fitting route bounds routeKey=$routeKey');
          unawaited(_fitRouteOverviewForState(state, animated: false));
        } else {
          _debugLog('[MAP_AUTOFOLLOW] skip fit: route already fitted routeKey=$routeKey');
        }
      }
    }
  }

  String _buildOverlaySignature({
    required ClientRideState state,
    required Set<Marker> markers,
    required Set<Polyline> polylines,
  }) {
    final markerIds = markers.map((m) => m.markerId.value).toList()..sort();
    final polyIds = polylines.map((p) => p.polylineId.value).toList()..sort();
    return '${state.status}|'
        'o:${state.originLatLng}|d:${state.destLatLng}|'
        'ride:${state.activeRide?.id}|'
        'markers:${markerIds.join(",")}|'
        'polys:${polyIds.join(",")}|'
        'destIcon:${_destIconLabelKey ?? "-"}|'
        'user:${_userLocationLatLng?.latitude.toStringAsFixed(5)},'
        '${_userLocationLatLng?.longitude.toStringAsFixed(5)}';
  }

  LatLngBounds _boundsFromLatLngs(LatLng a, LatLng b) {
    final southWest = LatLng(
      a.latitude < b.latitude ? a.latitude : b.latitude,
      a.longitude < b.longitude ? a.longitude : b.longitude,
    );
    final northEast = LatLng(
      a.latitude > b.latitude ? a.latitude : b.latitude,
      a.longitude > b.longitude ? a.longitude : b.longitude,
    );
    return LatLngBounds(southwest: southWest, northeast: northEast);
  }

  void _applyOriginNameToCenterLabel(ClientRideState state) {
    if (state.originName == null || state.originName!.trim().isEmpty) return;
    final label = CustomMapMarkers.streetLabelFromAddress(state.originName);
    if (label == 'Buscando…') return;
    _centerPinStreetLabel = label;
  }

  /// Alto del pin por encima de su punta (cuerpo + sombra). El encuadre se
  /// calcula con las coordenadas, que son la punta: sin este margen arriba,
  /// un pin en el borde superior quedaría tapado por la cabecera.
  static const double _pinHeadroom = 56;

  /// Padding del GoogleMap: las zonas tapadas solo cuentan con la ruta a la
  /// vista (sin pin central).
  EdgeInsets get _effectiveMapPadding => widget.allowPinSelection
      ? EdgeInsets.zero
      : widget.routePadding + const EdgeInsets.only(top: _pinHeadroom);

  /// Margen extra alrededor de la ruta al encuadrarla. Con [routePadding] el
  /// mapa ya excluye cabecera y panel, así que basta un margen moderado.
  double get _routeFitPadding =>
      widget.routePadding == EdgeInsets.zero ? 120 : 72;

  @override
  void didUpdateWidget(covariant ClientMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPadding =
        oldWidget.allowPinSelection
            ? EdgeInsets.zero
            : oldWidget.routePadding + const EdgeInsets.only(top: _pinHeadroom);
    if (oldPadding != _effectiveMapPadding) {
      // Cambió la zona visible (p. ej. el panel creció al fijar el destino):
      // se vuelve a encuadrar la ruta cuando el mapa ya aplicó el padding.
      Future<void>.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        final state = context.read<ClientRideBloc>().state;
        if (!widget.allowPinSelection &&
            state.activeRide == null &&
            state.originLatLng != null &&
            state.destLatLng != null) {
          unawaited(_fitRouteOverviewForState(state));
        }
      });
    }
    if (oldWidget.editDestination != widget.editDestination &&
        oldWidget.allowPinSelection == widget.allowPinSelection &&
        widget.allowPinSelection) {
      // Cambia qué punto marca el pin (origen ↔ destino) sin salir del modo
      // pin: la cámara vuelve a centrarse en el punto que se edita.
      _didInitialPickupAutoZoom = false;
      _mapAutoFollowEnabled = true;
      _cameraMoveStartLatLng = null;
      _centerPinStreetLabel = null;
      _pickupPreviewLatLng = null;
      scheduleMicrotask(() {
        if (!mounted) return;
        _updateMapOverlays(context.read<ClientRideBloc>().state);
      });
    }
    if (oldWidget.allowPinSelection != widget.allowPinSelection) {
      if (widget.allowPinSelection) {
        _centerPinStreetLabel = null;
        _pickupPreviewLatLng = null;
        // Se reactiva el pin de recojo: la cámara debe volver al origen
        // antes de que un arrastre lo mueva (si no, el primer gesto lo
        // llevaría al centro de la vista de ruta).
        _didInitialPickupAutoZoom = false;
        _mapAutoFollowEnabled = true;
        _cameraMoveStartLatLng = null;
      }
      // Cambia qué marcadores se dibujan (pin central vs. marcadores A/B).
      scheduleMicrotask(() {
        if (!mounted) return;
        _updateMapOverlays(context.read<ClientRideBloc>().state);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    widget.originFocusNode.addListener(_onMapFocusChanged);
    widget.destFocusNode.addListener(_onMapFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadClientMapIcons(context);
    });
  }

  @override
  void dispose() {
    widget.originFocusNode.removeListener(_onMapFocusChanged);
    widget.destFocusNode.removeListener(_onMapFocusChanged);
    widget.mapGestureActiveNotifier.value = false;
    _mapInactivityTimer?.cancel();
    _searchSmoothTimer?.cancel();
    _reverseGeocodeDebounce?.cancel();
    _routeDrawController?.dispose();
    _userPositionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mapError != null) {
      return Center(
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
      );
    }

    return BlocConsumer<ClientRideBloc, ClientRideState>(
      listenWhen: (previous, current) {
        return previous.status != current.status ||
            previous.originLatLng != current.originLatLng ||
            previous.destLatLng != current.destLatLng ||
            previous.destName != current.destName ||
            previous.originName != current.originName ||
            previous.routePolyline != current.routePolyline ||
            previous.routeDistanceKm != current.routeDistanceKm ||
            previous.routeDurationSeconds != current.routeDurationSeconds ||
            previous.activeRide != current.activeRide;
      },
      buildWhen: (previous, current) {
        // Evita rebuild del PlatformView del mapa por cambios de UI (p.ej. mapGestureActive),
        // que puede hacer que el gesto se sienta trabado.
        return previous.status != current.status ||
            previous.originLatLng != current.originLatLng ||
            previous.destLatLng != current.destLatLng ||
            previous.destName != current.destName ||
            previous.originName != current.originName ||
            previous.routePolyline != current.routePolyline ||
            previous.routeDistanceKm != current.routeDistanceKm ||
            previous.routeDurationSeconds != current.routeDurationSeconds ||
            previous.activeRide != current.activeRide ||
            previous.destName != current.destName;
      },
      listener: (context, state) {
        final enteredReadyToRequest =
            _trackedRideStatus != ClientRideStatus.readyToRequest &&
            state.status == ClientRideStatus.readyToRequest;
        final enteredSearchingDriver =
            _trackedRideStatus != ClientRideStatus.searchingDriver &&
            state.status == ClientRideStatus.searchingDriver;
        _trackedRideStatus = state.status;

        _handleSearchingCameraBehavior(state);
        if (state.status != ClientRideStatus.initial) {
          _destMapPinActive = false;
        }

        if (enteredReadyToRequest &&
            state.originLatLng != null &&
            state.destLatLng != null) {
          _destIconLabelKey = null;
          _mapAutoFollowEnabled = true;
          _lastAutoFittedRouteKey = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_fitRouteOverviewForState(state));
          });
        }

        if (enteredSearchingDriver && state.originLatLng != null) {
          _wasSearchingDriver = false;
          _mapAutoFollowEnabled = true;
          _cancelRoutePreviewAnimation();
          _lastAnimatedRoutePreviewKey = null;
          _searchPulseScreenOffset = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(_refreshSearchPulseScreenPosition(state.originLatLng!));
            _handleSearchingCameraBehavior(state);
          });
        }
        if (state.originLatLng != null &&
            state.originName != null &&
            !_isDestMapSelectionEnabled(state)) {
          final preview = _pickupPreviewLatLng ?? state.originLatLng!;
          if (_latLngAlmostEqual(preview, state.originLatLng!)) {
            _applyOriginNameToCenterLabel(state);
          }
        }
        scheduleMicrotask(() {
          if (!mounted) return;
          _updateMapOverlays(state);
        });
        _syncUserLocationStream(state);
        if (kDebugMode) {
          final sig =
              '${state.status}|o:${state.originLatLng}|d:${state.destLatLng}|'
              'poly:${state.routePolyline.length}|price:${state.offeredPrice}|'
              'mapErr:${_mapError != null}';
          if (sig != _debugLastRideSig) {
            _debugLastRideSig = sig;
            _debugLog(
              'ClientRideState → status=${state.status} '
              'origin=${state.originLatLng} dest=${state.destLatLng} '
              'routePts=${state.routePolyline.length} '
              'offeredPrice=${state.offeredPrice} '
              'markers=${_markers.length} polylines=${_polylines.length} '
              'showRouteSummary=${_shouldShowRouteSummary(state)}',
            );
          }
        }
      },
      builder: (context, state) {
        final showCenteredMapPin = _isMapPinSelectionEnabled(state);
        final isDestCenterPin = _isDestMapSelectionEnabled(state);
        final centerPinLabel = _centerPinLabelForState(state);
        return Stack(
          fit: StackFit.expand,
          children: [
            GoogleMap(
              // Sin edificios 3D: al acercar se dibujan con lados sombreados
              // oscuros que rompen el estilo claro.
              buildingsEnabled: false,
              onMapCreated: _onMapCreated,
              onTap: (_) {
                if (_isMapPinSelectionEnabled(state)) {
                  _dismissSearchKeyboard();
                }
              },
              onCameraMoveStarted: () {
                _onMapCameraMoveStarted();
              },
              onCameraMove: (p) {
                _onMapCameraMoveForSearchPulse(state);
                _onMapCameraMove(p, state);
              },
              onCameraIdle: () {
                _onMapCameraIdle(state);
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(
                  AppConstants.trujilloLatitude,
                  AppConstants.trujilloLongitude,
                ),
                zoom: AppConstants.defaultZoom - 0.6,
              ),
              mapType: MapType.normal,
              myLocationEnabled: _useNativeMyLocation(state),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: true,
              rotateGesturesEnabled: true,
              // En algunos dispositivos (MIUI/Android) EagerGestureRecognizer
              // puede degradar el render del SurfaceView del mapa; usamos
              // recognizers explícitos para pan/zoom/tap.
              gestureRecognizers:
                  <Factory<OneSequenceGestureRecognizer>>{
                    Factory<PanGestureRecognizer>(
                      () => PanGestureRecognizer(),
                    ),
                    Factory<ScaleGestureRecognizer>(
                      () => ScaleGestureRecognizer(),
                    ),
                    Factory<TapGestureRecognizer>(
                      () => TapGestureRecognizer(),
                    ),
                  },
              padding: _effectiveMapPadding,
              markers: _markers,
              polylines: _polylines,
              circles: _searchCircles,
            ),
            // Pin «gota» con la punta en el centro exacto del mapa (el punto
            // que se guarda): azul para el recojo, rojo para el destino.
            if (showCenteredMapPin)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CenterPinPainter(
                      label: centerPinLabel,
                      color: isDestCenterPin
                          ? CustomMapMarkers.destPinColor
                          : AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),
            if (_isSearchIdleMapView(state) &&
                state.originLatLng != null &&
                _searchPulseScreenOffset != null)
              Positioned(
                left: _searchPulseScreenOffset!.dx - 70,
                top: _searchPulseScreenOffset!.dy - 70,
                width: 140,
                height: 140,
                child: IgnorePointer(
                  child: _SearchingOriginPulse(
                    controller: widget.searchPulseController,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SearchingOriginPulse extends StatelessWidget {
  const _SearchingOriginPulse({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140 + 40 * t,
              height: 140 + 40 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withValues(alpha: 0.12 * (1 - t)),
              ),
            ),
            Container(
              width: 110 + 20 * t,
              height: 110 + 20 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryBlue.withValues(alpha: 0.2 * (1 - t)),
              ),
            ),
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.darkSurface,
              ),
              child: const Icon(
                Icons.local_taxi,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
            ),
          ],
        );
      },
    );
  }
}

