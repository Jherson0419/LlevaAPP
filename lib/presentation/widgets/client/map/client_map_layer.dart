import 'dart:async';
import 'dart:developer' show log;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/client_ride_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/custom_map_markers.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';

/// Capa de mapa aislada: marcadores, polilíneas y cámara sin `setState` en el dashboard.
class ClientMapLayer extends StatefulWidget {
  const ClientMapLayer({super.key});

  @override
  State<ClientMapLayer> createState() => _ClientMapLayerState();
}

class _ClientMapLayerState extends State<ClientMapLayer> {
  GoogleMapController? _mapController;
  String? _mapError;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _originIcon;
  BitmapDescriptor? _destIcon;

  Timer? _mapInactivityTimer;
  bool _mapAutoFollowEnabled = true;
  int _programmaticCameraMoveCount = 0;

  String? _debugLastRideSig;

  void _debugLog(String message, {int level = 800}) {
    if (!kDebugMode) return;
    log(message, name: 'LlevaClientDashboard', level: level);
  }

  bool get _isProgrammaticCameraMove => _programmaticCameraMoveCount > 0;

  void _onMapCameraMoveStarted() {
    if (_isProgrammaticCameraMove) return;
    _mapInactivityTimer?.cancel();
    if (_mapAutoFollowEnabled) {
      setState(() {
        _mapAutoFollowEnabled = false;
      });
    }
  }

  void _onMapUserActivity() {
    if (_isProgrammaticCameraMove) return;
    _mapInactivityTimer?.cancel();
    _mapInactivityTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _mapAutoFollowEnabled = true;
      });
      _updateMapOverlays(context.read<ClientRideBloc>().state);
    });
  }

  Future<void> _animateMapCamera(CameraUpdate update) async {
    if (_mapController == null) return;
    _programmaticCameraMoveCount++;
    try {
      await _mapController!.animateCamera(update);
    } catch (_) {
      // Ignora errores transitorios de plataforma al animar cámara.
    } finally {
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
    try {
      origin = await CustomMapMarkers.createOriginMarker();
    } catch (_) {}
    try {
      dest = await CustomMapMarkers.createDestMarker();
    } catch (_) {}
    try {
      car = await CustomMapMarkers.createCarMarker();
    } catch (_) {}
    if (!context.mounted) return;
    setState(() {
      _carIcon = car;
      _originIcon = origin;
      _destIcon = dest;
    });
    final rideBloc = context.read<ClientRideBloc>();
    _updateMapOverlays(rideBloc.state);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setMapStyle();
    _debugLog('GoogleMap onMapCreated: controlador asignado');
    setState(() {
      _mapError = null;
    });
  }

  void _setMapStyle() {
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

  bool _shouldShowRouteSummary(ClientRideState state) {
    if (state.originLatLng != null && state.destLatLng != null) {
      return true;
    }
    return state.activeRide != null;
  }

  void _updateMapOverlays(ClientRideState state) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (state.originLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: state.originLatLng!,
          anchor: _originIcon != null
              ? const Offset(0.5, 0.5)
              : const Offset(0.5, 1.0),
          icon: _originIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
        ),
      );
    }

    if (state.destLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest'),
          position: state.destLatLng!,
          anchor: _destIcon != null
              ? const Offset(0.5, 0.5)
              : const Offset(0.5, 1.0),
          icon: _destIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
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
          infoWindow: const InfoWindow(
            title: 'Conductor',
          ),
        ),
      );
    }

    if (state.routePolyline.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routePolyline,
          color: const Color(0xFF00D4FF),
          width: 4,
        ),
      );
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });

    if (_mapController != null && _mapAutoFollowEnabled) {
      final ride = state.activeRide;
      if ((state.status == ClientRideStatus.driverAssigned ||
              state.status == ClientRideStatus.driverArrived) &&
          state.originLatLng != null &&
          ride != null &&
          ride.driverLat != null &&
          ride.driverLng != null) {
        final driverPos = LatLng(ride.driverLat!, ride.driverLng!);
        final bounds = _boundsFromLatLngs(state.originLatLng!, driverPos);
        _animateMapCamera(
          CameraUpdate.newLatLngBounds(bounds, 160),
        );
      } else if (state.status == ClientRideStatus.searchingDriver &&
          state.destLatLng != null) {
        _animateMapCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: state.destLatLng!,
              zoom: AppConstants.defaultZoom - 0.2,
            ),
          ),
        );
      } else if (state.originLatLng != null && state.destLatLng != null) {
        final bounds = _boundsFromLatLngs(
          state.originLatLng!,
          state.destLatLng!,
        );
        _animateMapCamera(CameraUpdate.newLatLngBounds(bounds, 140));
      }
    }
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadClientMapIcons(context);
    });
  }

  @override
  void dispose() {
    _mapInactivityTimer?.cancel();
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
      listener: (context, state) {
        _updateMapOverlays(state);
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
        final routeLocked = state.routePolyline.isNotEmpty;
        return GoogleMap(
          onMapCreated: _onMapCreated,
          onCameraMoveStarted:
              routeLocked ? null : _onMapCameraMoveStarted,
          onCameraMove: routeLocked ? null : (_) => _onMapUserActivity(),
          onCameraIdle: routeLocked ? null : _onMapUserActivity,
          initialCameraPosition: const CameraPosition(
            target: LatLng(
              AppConstants.trujilloLatitude,
              AppConstants.trujilloLongitude,
            ),
            zoom: AppConstants.defaultZoom - 0.6,
          ),
          mapType: MapType.normal,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          scrollGesturesEnabled: !routeLocked,
          zoomGesturesEnabled: !routeLocked,
          tiltGesturesEnabled: !routeLocked,
          rotateGesturesEnabled: !routeLocked,
          markers: _markers,
          polylines: _polylines,
        );
      },
    );
  }
}
