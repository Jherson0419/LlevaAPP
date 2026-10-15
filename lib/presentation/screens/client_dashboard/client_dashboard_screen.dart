import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/enums/client_ride_status.dart';
import '../../../core/routes/home_navigation.dart';
import '../../../core/enums/client_vehicle_category.dart';
import '../../../core/services/places_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/client_ride_pricing.dart';
import '../../../core/utils/custom_map_markers.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../../domain/entities/top_driver_entity.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import '../../bloc/top_drivers/top_drivers_cubit.dart';
import '../../widgets/client/client_drawer.dart';
import '../../widgets/client/map/center_pin_painter.dart';
import '../../widgets/client/map/client_map_layer.dart';
import '../../widgets/client/ride_step_indicator.dart';
import '../../widgets/client/ride_trip_labels.dart';
import '../../widgets/client/vehicle_category_card.dart';
import '../client/payment_step_screen.dart';
import '../client/ride_flow_routes.dart';
import '../client/searching_driver_screen.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);

/// Clave de SharedPreferences con la última categoría de vehículo elegida.
const String _kVehicleCategoryPrefsKey = 'selected_vehicle_category';

/// Clave de SharedPreferences con los últimos destinos elegidos (máx. 10).
const String _kRecentDestinationsPrefsKey = 'recent_destinations';

/// Pasos de la búsqueda de destino a pantalla completa.
enum _SearchStep { none, mapWithOrigin, searchingDestination }

/// Punto que el pasajero está cambiando con el pin del mapa.
enum _EditingField { none, origin, destination }

/// Mínimo de caracteres para lanzar la búsqueda de destino en Places.
const int _kMinSearchChars = 3;

/// Espera máxima por resultados de Places antes de ofrecer continuar con el
/// texto escrito.
const Duration _kPlacesLoadingTimeout = Duration(seconds: 4);

/// Destino fijo con coordenadas: se elige sin consultar PlacesService.
typedef _Place = ({String name, String address, double lat, double lng});

const List<_Place> _kTrujilloSuggestions = [
  (
    name: 'Plaza de Armas de Trujillo',
    address: 'Centro Histórico, Trujillo',
    lat: -8.1091,
    lng: -79.0215,
  ),
  (
    name: 'Mall Aventura Trujillo',
    address: 'Av. César Vallejo, El Porvenir',
    lat: -8.0847,
    lng: -79.0023,
  ),
  (
    name: 'Real Plaza Trujillo',
    address: 'Av. César Vallejo 1345',
    lat: -8.1050,
    lng: -79.0198,
  ),
  (
    name: 'Universidad César Vallejo',
    address: 'Av. Larco 1770, Trujillo',
    lat: -8.1183,
    lng: -79.0289,
  ),
  (
    name: 'Hospital Regional de Trujillo',
    address: 'Av. Mansiche 795',
    lat: -8.1033,
    lng: -79.0369,
  ),
  (
    name: 'Aeropuerto Carlos Martínez de Pinillos',
    address: 'Huanchaco, Trujillo',
    lat: -8.0814,
    lng: -79.1083,
  ),
  (
    name: 'Huanchaco',
    address: 'Balneario de Huanchaco',
    lat: -8.0803,
    lng: -79.1197,
  ),
  (
    name: 'Chan Chan',
    address: 'Complejo Arqueológico',
    lat: -8.1047,
    lng: -79.0753,
  ),
  (
    name: 'UPAO Universidad',
    address: 'Av. América Sur 3145',
    lat: -8.1264,
    lng: -79.0347,
  ),
  (
    name: 'Terminal Terrestre El Alambre',
    address: 'Av. Túpac Amaru, Trujillo',
    lat: -8.1369,
    lng: -79.0164,
  ),
];

const List<_Place> _kPopularDestinations = [
  (
    name: 'Plaza de Armas de Trujillo',
    address: 'Centro Histórico, Trujillo',
    lat: -8.1091,
    lng: -79.0215,
  ),
];

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ClientMapLayer los exige; en este flujo ningún campo de texto los usa.
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destFocusNode = FocusNode();
  late final AnimationController _pulseController;

  final GlobalKey _mapLayerKey = GlobalKey();

  /// Pestaña Mapa: se crea la primera vez que se abre y desde entonces
  /// queda viva en el IndexedStack; la clave permite reiniciar su pin.
  final GlobalKey<_MapTabViewState> _mapTabKey = GlobalKey<_MapTabViewState>();
  bool _mapTabCreated = false;
  final ValueNotifier<bool> _mapGestureActive = ValueNotifier<bool>(false);

  /// 0 = Inicio (pantalla blanca sin mapa), 1 = Mapa (mapa libre, sin panel).
  int _currentTab = 0;

  /// Paso actual de la búsqueda de destino a pantalla completa.
  _SearchStep _searchStep = _SearchStep.none;
  final TextEditingController _destSearchController = TextEditingController();
  List<String> _recentDestinations = [];

  /// Punto que se está cambiando moviendo el mapa con la ruta ya definida
  /// (ver [_onOriginFieldTap] y [_onDestinationFieldTap]), y su valor antes
  /// de editarlo: la edición termina cuando el bloc confirma uno nuevo.
  _EditingField _editingField = _EditingField.none;
  LatLng? _valueBeforeEdit;

  /// true mientras se esperan resultados de Places para lo escrito.
  bool _placesLoading = false;
  Timer? _placesLoadingTimer;

  /// Estado anterior del viaje, para detectar el regreso al reposo desde la
  /// tarifa o desde un viaje cancelado.
  ClientRideStatus? _previousRideStatus;

  /// true mientras la pantalla del viaje está abierta sobre el dashboard.
  bool _rideScreenOpen = false;

  /// Bloc del viaje. Lo crea y lo cierra esta pantalla, que lo provee a su
  /// subárbol: los métodos del State no pueden leerlo con `context.read`,
  /// porque su `context` queda por encima del BlocProvider.
  late final ClientRideBloc _rideBloc;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    final authState = context.read<AuthBloc>().state;
    final clientId =
        authState is AuthAuthenticated ? authState.user.id.trim() : '';
    _rideBloc = di.sl<ClientRideBloc>()
      // Recién salido de la pantalla de permisos no se repite el diálogo:
      // el usuario ya decidió ahí.
      ..add(
        InitializePickupFromCurrentLocation(
          askPermission: !PermissionsSession.handled,
        ),
      )
      ..add(CheckActiveRide(clientId));
    unawaited(_restoreVehicleCategory(_rideBloc));
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const RefreshProfileEvent());
    });
    _loadRecentDestinations().then((recents) {
      if (!mounted) return;
      setState(() => _recentDestinations = recents);
    });
  }

  /// Al volver a la app (p. ej. desde los ajustes de ubicación) se reintenta
  /// leer el GPS si antes había fallado y ahora ya está disponible.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final rideState = _rideBloc.state;
    if (!rideState.locationDenied || rideState.originLatLng != null) return;
    unawaited(_retryLocationIfAvailable());
  }

  /// Solo reintenta con el GPS encendido y el permiso concedido: el propio
  /// diálogo de permiso pausa y reanuda la app, y reintentar tras una
  /// negativa volvería a mostrarlo en bucle.
  Future<void> _retryLocationIfAvailable() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return;
      }
    } catch (_) {
      return;
    }
    if (!mounted || _rideBloc.isClosed) return;
    _rideBloc.add(const InitializePickupFromCurrentLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _placesLoadingTimer?.cancel();
    _destSearchController.dispose();
    _originFocusNode.dispose();
    _destFocusNode.dispose();
    _pulseController.dispose();
    _mapGestureActive.dispose();
    unawaited(_rideBloc.close());
    super.dispose();
  }

  void _setSearchStep(_SearchStep step) {
    if (step != _SearchStep.searchingDestination) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() {
      _searchStep = step;
      // Cambiar de paso (abrir el buscador, volver, elegir destino)
      // cancela la edición del origen.
      _editingField = _EditingField.none;
    });
  }

  /// Toque en la fila de origen: el pin azul pasa a marcar el origen y,
  /// al soltar el mapa en otro sitio, ese punto queda como nuevo origen.
  /// Sin destino el pin de recojo ya está activo; con ruta definida se
  /// reactiva (la cámara vuelve al origen) hasta que el origen cambie.
  void _onOriginFieldTap() {
    final state = _rideBloc.state;
    if (state.originLatLng == null) return;
    setState(() {
      _valueBeforeEdit = state.originLatLng;
      _editingField = _EditingField.origin;
    });
  }

  /// Toque en la fila de destino. Con destino ya fijado se cambia en el
  /// mismo mapa con el pin rojo; sin destino se abre el buscador.
  void _onDestinationFieldTap() {
    final state = _rideBloc.state;
    if (state.originLatLng == null || state.destLatLng == null) {
      _openDestinationSearchPanel();
      return;
    }
    setState(() {
      _valueBeforeEdit = state.destLatLng;
      _editingField = _EditingField.destination;
    });
  }

  /// Termina la edición sin cambiar nada (el punto queda como estaba).
  void _cancelEditing() {
    if (_editingField == _EditingField.none) return;
    setState(() => _editingField = _EditingField.none);
  }

  /// «Continuar al pago»: abre el paso 2 como pantalla aparte. Mientras está
  /// abierta, el dashboard queda en el inicio (sin mapa debajo: la pantalla
  /// de pago trae su propia vista previa); al cerrarse se retoma el mapa con
  /// origen y destino si el viaje sigue sin pedirse.
  Future<void> _openPaymentStep() async {
    _setSearchStep(_SearchStep.none);
    await Navigator.of(context).push(
      rideFlowRoute<void>(
        (_) => BlocProvider.value(
          value: _rideBloc,
          child: const PaymentStepScreen(),
        ),
      ),
    );
    if (!mounted) return;
    final state = _rideBloc.state;
    final idle = state.activeRide == null &&
        (state.status == ClientRideStatus.initial ||
            state.status == ClientRideStatus.error);
    if (idle && state.originLatLng != null && state.destLatLng != null) {
      _setSearchStep(_SearchStep.mapWithOrigin);
    }
  }

  /// Abre la pantalla del viaje (búsqueda de conductor → fin del trayecto)
  /// encima de lo que haya: el paso de vehículo al pedir, o el dashboard
  /// al recuperar un viaje activo. Ella misma se cierra cuando ya no hay
  /// viaje.
  Future<void> _openRideScreen() async {
    if (_rideScreenOpen) return;
    _rideScreenOpen = true;
    await Navigator.of(context).push(
      rideFlowRoute<void>(
        (_) => BlocProvider.value(
          value: _rideBloc,
          child: const SearchingDriverScreen(),
        ),
      ),
    );
    _rideScreenOpen = false;
  }

  /// Pestañas Soporte y Perfil: abren su pantalla y, al volver, el dashboard
  /// queda en Inicio.
  Future<void> _openTabRoute(String location) async {
    await context.push(location);
    if (!mounted) return;
    setState(() => _currentTab = 0);
  }

  /// Pestaña Mapa: la crea la primera vez; las siguientes, como ya está
  /// viva, solo reinicia el pin sobre la ubicación del pasajero.
  void _openMapTab() {
    if (_currentTab == 1) return;
    final firstTime = !_mapTabCreated;
    setState(() {
      _currentTab = 1;
      _mapTabCreated = true;
    });
    if (!firstTime) _mapTabKey.currentState?.resetPin();
  }

  /// «Pedir taxi aquí» en la pestaña Mapa: pasa a la búsqueda de destino.
  /// Si el pasajero movió el pin, ese punto es el nuevo recojo.
  void _requestRideFromMap(LatLng? pin) {
    if (pin != null) _rideBloc.add(PickupPinMoved(pin));
    setState(() {
      _currentTab = 0;
      _searchStep = _SearchStep.mapWithOrigin;
      _editingField = _EditingField.none;
    });
  }

  /// Abre el buscador de destino con el campo vacío.
  void _openDestinationSearchPanel() {
    _destSearchController.clear();
    _setSearchStep(_SearchStep.searchingDestination);
  }

  /// Flecha atrás (o botón atrás del sistema) dentro de la búsqueda: del
  /// buscador vuelve al mapa con el origen; del mapa, al inicio.
  void _backFromSearch() {
    // Editando origen o destino, «atrás» solo cancela la edición.
    if (_searchStep == _SearchStep.mapWithOrigin &&
        _editingField != _EditingField.none) {
      _cancelEditing();
      return;
    }
    _setSearchStep(
      _searchStep == _SearchStep.searchingDestination
          ? _SearchStep.mapWithOrigin
          : _SearchStep.none,
    );
  }

  /// Mantiene [_searchStep] coherente con el estado del viaje.
  void _syncSearchStepWithRide(ClientRideState state) {
    final previous = _previousRideStatus;
    _previousRideStatus = state.status;

    bool isIdleStatus(ClientRideStatus? s) =>
        s == null ||
        s == ClientRideStatus.initial ||
        s == ClientRideStatus.error;
    final idleNow = state.activeRide == null && isIdleStatus(state.status);

    _SearchStep next = _searchStep;
    if (!idleNow) {
      // Tarifa o viaje en curso: mandan los paneles del mapa.
      next = _SearchStep.none;
    } else if (state.originLatLng == null) {
      // Flujo reiniciado: de vuelta al inicio.
      if (!isIdleStatus(previous)) next = _SearchStep.none;
    } else if (!isIdleStatus(previous)) {
      // Regreso al reposo conservando el origen («editar ruta» desde la
      // tarifa, viaje cancelado o un error): se retoma en el mapa con
      // origen y destino en vez de caer en el inicio.
      next = _SearchStep.mapWithOrigin;
    }
    if (next != _searchStep) setState(() => _searchStep = next);
  }

  Future<List<String>> _loadRecentDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kRecentDestinationsPrefsKey) ?? [];
  }

  Future<void> _saveRecentDestination(String name) async {
    final recents = List<String>.of(_recentDestinations)
      ..remove(name) // sin duplicados
      ..insert(0, name);
    final trimmed = recents.take(10).toList();
    if (mounted) setState(() => _recentDestinations = trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kRecentDestinationsPrefsKey, trimmed);
  }

  /// Texto del buscador: desde [_kMinSearchChars] caracteres lanza la
  /// búsqueda en Places y muestra el indicador de carga hasta que llegan
  /// resultados o pasa [_kPlacesLoadingTimeout] (el bloc no avisa cuando una
  /// búsqueda termina sin resultados).
  void _onDestQueryChanged(String value) {
    _placesLoadingTimer?.cancel();
    final shouldSearch = value.trim().length >= _kMinSearchChars;
    setState(() => _placesLoading = shouldSearch);
    if (!shouldSearch) return;
    _rideBloc.add(DestTextChanged(value));
    _placesLoadingTimer = Timer(_kPlacesLoadingTimeout, () {
      if (!mounted) return;
      setState(() => _placesLoading = false);
    });
  }

  /// Destino escrito a mano sin resultados en Places: se continúa con ese
  /// nombre y una ubicación aproximada (centro de Trujillo).
  void _selectTypedDestination(String text) {
    final name = text.trim();
    if (name.isEmpty) return;
    unawaited(_saveRecentDestination(name));
    _rideBloc.add(
          DestCoordinatesSelected(
            name: name,
            lat: ClientRideBloc.fallbackDestLatLng.latitude,
            lng: ClientRideBloc.fallbackDestLatLng.longitude,
          ),
        );
    _setSearchStep(_SearchStep.mapWithOrigin);
  }

  /// Destino sugerido o concurrido: trae coordenadas, así que se fija sin
  /// consultar PlacesService.
  void _selectSuggestedDestination(_Place place) {
    unawaited(_saveRecentDestination(place.name));
    _rideBloc.add(
          DestCoordinatesSelected(
            name: place.name,
            lat: place.lat,
            lng: place.lng,
          ),
        );
    _setSearchStep(_SearchStep.mapWithOrigin);
  }

  /// Destino reciente: se guarda solo el nombre. Si coincide con un
  /// sugerido se usan sus coordenadas; si no (vino de una búsqueda), se
  /// resuelve con Places ([DestSelected]) y, si Places no lo encuentra, el
  /// nombre queda escrito en el buscador para elegir entre los resultados.
  Future<void> _selectRecentDestination(String name) async {
    for (final place in _kTrujilloSuggestions) {
      if (place.name == name) {
        _selectSuggestedDestination(place);
        return;
      }
    }

    final rideBloc = _rideBloc;
    unawaited(_saveRecentDestination(name));
    _setSearchStep(_SearchStep.mapWithOrigin);

    List<Prediction> matches = const [];
    try {
      matches = await di.sl<PlacesService>().searchPlaces(
            name,
            near: rideBloc.state.originLatLng,
            cityHint: 'trujillo',
          );
    } catch (_) {
      // Sin red o sin respuesta: se cae al modo manual de abajo.
    }
    if (!mounted || rideBloc.isClosed) return;

    if (matches.isNotEmpty) {
      final match = matches.first;
      rideBloc.add(DestSelected(match.placeId, match.description));
      return;
    }
    _destSearchController.text = name;
    rideBloc.add(DestTextChanged(name));
    _setSearchStep(_SearchStep.searchingDestination);
  }

  /// Destino marcado con el pin rojo del mapa: se guarda tal cual (sus
  /// coordenadas y la calle bajo el pin) y se vuelve al mapa con la ruta.
  void _selectPinDestination(LatLng position, String label) {
    unawaited(_saveRecentDestination(label));
    _rideBloc.add(
      DestCoordinatesSelected(
        name: label,
        lat: position.latitude,
        lng: position.longitude,
      ),
    );
    _setSearchStep(_SearchStep.mapWithOrigin);
  }

  /// Resultado de la búsqueda escrita: ya trae placeId.
  void _selectPrediction(Prediction prediction) {
    unawaited(_saveRecentDestination(prediction.description));
    _rideBloc.add(DestSelected(prediction.placeId, prediction.description));
    _setSearchStep(_SearchStep.mapWithOrigin);
  }

  Future<void> _saveVehicleCategory(ClientVehicleCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVehicleCategoryPrefsKey, category.name);
  }

  /// Aplica al abrir el dashboard la última categoría elegida en las
  /// tarjetas de vehículo.
  Future<void> _restoreVehicleCategory(ClientRideBloc bloc) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kVehicleCategoryPrefsKey) ?? 'standard';
    final category = ClientVehicleCategory.values.firstWhere(
      (c) => c.name == saved,
      orElse: () => ClientVehicleCategory.standard,
    );
    if (bloc.isClosed || category == bloc.state.vehicleCategory) return;
    bloc.add(VehicleCategoryChanged(category));
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ClientRideBloc>.value(value: _rideBloc),
        BlocProvider<TopDriversCubit>(
          create: (_) => di.sl<TopDriversCubit>(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final drawerWidth = MediaQuery.sizeOf(context).width * 0.78;

          // Con la búsqueda de destino abierta o en la pestaña Mapa, «atrás»
          // vuelve al inicio en vez de salir del dashboard.
          return PopScope(
            canPop: _searchStep == _SearchStep.none && _currentTab == 0,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              final scaffold = _scaffoldKey.currentState;
              if (scaffold != null && scaffold.isDrawerOpen) {
                scaffold.closeDrawer();
                return;
              }
              if (_searchStep != _SearchStep.none) {
                _backFromSearch();
              } else {
                setState(() => _currentTab = 0);
              }
            },
            child: Scaffold(
              key: _scaffoldKey,
              backgroundColor: Colors.white,
              // En el buscador de destino el teclado no redimensiona el
              // body: el panel queda fijo y solo se desplaza su lista.
              resizeToAvoidBottomInset:
                  _searchStep != _SearchStep.searchingDestination,
              drawer: Drawer(
                width: drawerWidth,
                backgroundColor: const Color(0xFF0A0A0A),
                child: ClientDrawer(
                  hostContext: context,
                  onCityTap: () {},
                ),
              ),
              // Las pestañas solo se ven en reposo: ni en la búsqueda de
              // destino (pantalla completa) ni con una solicitud o un viaje
              // en marcha.
              bottomNavigationBar:
                  BlocSelector<ClientRideBloc, ClientRideState, bool>(
                selector: (state) =>
                    state.status != ClientRideStatus.initial &&
                    state.status != ClientRideStatus.error,
                builder: (context, isActiveRide) {
                  if (isActiveRide || _searchStep != _SearchStep.none) {
                    return const SizedBox.shrink();
                  }
                  return _DashboardTabBar(
                    currentTab: _currentTab,
                    onHomeTap: () => setState(() => _currentTab = 0),
                    onMapTap: _openMapTab,
                    onSupportTap: () => _openTabRoute('/client-support'),
                    onProfileTap: () => _openTabRoute('/client-profile'),
                  );
                },
              ),
              body: BlocListener<ClientRideBloc, ClientRideState>(
                listener: (context, state) {
                  _syncSearchStepWithRide(state);
                  final idle = state.activeRide == null &&
                      (state.status == ClientRideStatus.initial ||
                          state.status == ClientRideStatus.error);
                  if (!idle) {
                    unawaited(_openRideScreen());
                  } else if (!_rideScreenOpen &&
                      state.status == ClientRideStatus.error &&
                      state.errorMessage != null) {
                    // El pedido no llegó a enviarse (la pantalla del viaje
                    // avisa por su cuenta cuando ya está abierta).
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(state.errorMessage!),
                          backgroundColor: AppTheme.errorRed,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  }
                  final editedNow = switch (_editingField) {
                    _EditingField.origin => state.originLatLng,
                    _EditingField.destination => state.destLatLng,
                    _EditingField.none => null,
                  };
                  if (_editingField != _EditingField.none &&
                      editedNow != _valueBeforeEdit) {
                    // Punto confirmado al soltar el pin: termina la edición
                    // y el mapa vuelve a mostrar la ruta completa.
                    setState(() => _editingField = _EditingField.none);
                  }
                  if (_placesLoading && state.destPredictions.isNotEmpty) {
                    // Llegaron resultados: fin de la espera del buscador.
                    _placesLoadingTimer?.cancel();
                    setState(() => _placesLoading = false);
                  }
                },
                child: BlocSelector<ClientRideBloc, ClientRideState, bool>(
                  selector: (state) =>
                      state.activeRide == null &&
                      (state.status == ClientRideStatus.initial ||
                          state.status == ClientRideStatus.error),
                  builder: (context, idle) {
                    void openDrawer() =>
                        _scaffoldKey.currentState?.openDrawer();

                    final inSearch = _searchStep != _SearchStep.none && idle;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Inicio y Mapa viven siempre en un IndexedStack: al
                        // cambiar de pestaña no se destruyen (el mapa nativo
                        // se crea una sola vez, la primera vez que se abre la
                        // pestaña). Con la búsqueda o un viaje encima quedan
                        // ocultos, sin perder su estado.
                        Offstage(
                          offstage: inSearch || !idle,
                          child: IndexedStack(
                            index: _currentTab == 1 ? 1 : 0,
                            children: [
                              _DashboardHome(
                                onMenuTap: openDrawer,
                                onSearchTap: () =>
                                    _setSearchStep(_SearchStep.mapWithOrigin),
                                onCategoryConfirmed: (category) {
                                  _rideBloc
                                      .add(VehicleCategoryChanged(category));
                                  unawaited(_saveVehicleCategory(category));
                                  _setSearchStep(_SearchStep.mapWithOrigin);
                                },
                              ),
                              if (_mapTabCreated)
                                _MapTabView(
                                  key: _mapTabKey,
                                  onRequestRide: _requestRideFromMap,
                                )
                              else
                                const SizedBox.shrink(),
                            ],
                          ),
                        ),

                        // Búsqueda de destino: mapa con origen/destino y,
                        // encima, el buscador.
                        if (inSearch)
                          _SearchFlowView(
                            step: _searchStep,
                            mapLayerKey: _mapLayerKey,
                            mapGestureActiveNotifier: _mapGestureActive,
                            searchPulseController: _pulseController,
                            originFocusNode: _originFocusNode,
                            destFocusNode: _destFocusNode,
                            searchController: _destSearchController,
                            recentDestinations: _recentDestinations,
                            onBack: _backFromSearch,
                            editingField: _editingField,
                            onCancelEditing: _cancelEditing,
                            onOriginFieldTap: _onOriginFieldTap,
                            onDestinationFieldTap: _onDestinationFieldTap,
                            onSearchDestination: _openDestinationSearchPanel,
                            onContinue: _openPaymentStep,
                            isLoadingResults: _placesLoading,
                            onQueryChanged: _onDestQueryChanged,
                            onTypedDestinationSelected:
                                _selectTypedDestination,
                            // Un solo destino concurrido: se elige directo,
                            // sin hoja intermedia.
                            onPopularTap: () => _selectSuggestedDestination(
                              _kPopularDestinations.first,
                            ),
                            onRecentSelected: _selectRecentDestination,
                            onSuggestionSelected: _selectSuggestedDestination,
                            onPredictionSelected: _selectPrediction,
                            onPinConfirmed: _selectPinDestination,
                          ),

                        // Solicitud o viaje en curso: lo muestra la pantalla
                        // del viaje, que se abre encima ([_openRideScreen]).
                        if (!idle)
                          const ColoredBox(
                            color: Colors.white,
                            child: Center(
                              child: CircularProgressIndicator(color: _kBlue),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pestaña Mapa: mapa a pantalla completa con un pin fijo en el centro para
/// elegir dónde pedir el taxi, la dirección bajo el pin arriba y el botón
/// «Pedir taxi aquí» abajo. El dashboard la mantiene viva entre cambios de
/// pestaña y llama a [_MapTabViewState.resetPin] al volver a ella.
class _MapTabView extends StatefulWidget {
  const _MapTabView({super.key, required this.onRequestRide});

  /// «Pedir taxi aquí». Recibe el punto bajo el pin si el pasajero movió el
  /// mapa; `null` si no lo movió (se usa el recojo actual).
  final ValueChanged<LatLng?> onRequestRide;

  @override
  State<_MapTabView> createState() => _MapTabViewState();
}

class _MapTabViewState extends State<_MapTabView> {
  /// Centro de Trujillo: cámara inicial mientras no hay ubicación.
  static const LatLng _fallbackCenter = LatLng(-8.1091, -79.0215);
  static const double _zoom = 15;

  /// No se vuelve a buscar la dirección si el pin se movió menos que esto.
  static const double _regeocodeMeters = 10;

  GoogleMapController? _mapController;

  /// Estilo claro compartido con el selector de destino: si ya se leyó, el
  /// primer cuadro sale con él.
  String? _mapStyle = _lightMapStyleCache;

  /// Centro de la cámara (donde apunta la punta del pin).
  LatLng? _currentPinPosition;
  bool _pinMoved = false;

  /// Calle bajo el pin: etiqueta sobre el pin y texto de la barra superior.
  String _pinLabel = '';
  String _pinStreetName = '';

  /// Última posición cuya dirección se pidió, y turno de la petición en
  /// curso (una respuesta vieja no pisa a una nueva).
  LatLng? _lastGeocodedPosition;
  int _geocodeToken = 0;

  @override
  void initState() {
    super.initState();
    if (_mapStyle == null) {
      _loadLightMapStyle().then((style) {
        if (mounted && style != null) setState(() => _mapStyle = style);
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _centerOn(LatLng? target) {
    final controller = _mapController;
    if (target == null || controller == null) return;
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, _zoom));
  }

  /// Al volver a la pestaña: el pin vuelve a la ubicación real del pasajero
  /// (la última que conoce el GPS o, si no hay, el recojo actual) y se
  /// olvida la dirección mostrada.
  Future<void> resetPin() async {
    _geocodeToken++;
    setState(() {
      _pinMoved = false;
      _currentPinPosition = null;
      _lastGeocodedPosition = null;
      _pinLabel = '';
      _pinStreetName = '';
    });
    LatLng? target;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) target = LatLng(last.latitude, last.longitude);
    } catch (_) {
      // Sin permiso o sin dato: se usa el recojo actual.
    }
    if (!mounted) return;
    target ??= context.read<ClientRideBloc>().state.originLatLng;
    _centerOn(target);
  }

  /// La cámara se detuvo: busca la calle bajo el pin.
  Future<void> _onCameraIdle() async {
    final position = _currentPinPosition;
    if (position == null) return;
    final last = _lastGeocodedPosition;
    if (last != null &&
        Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              position.latitude,
              position.longitude,
            ) <
            _regeocodeMeters) {
      return;
    }
    _lastGeocodedPosition = position;
    final token = ++_geocodeToken;
    setState(() => _pinLabel = CenterPinPainter.loadingLabel);

    String? address;
    try {
      address = await di.sl<PlacesService>().reverseGeocode(position);
    } catch (_) {
      address = null;
    }
    if (!mounted || token != _geocodeToken) return;
    setState(() {
      if (address != null) {
        final shortName = _DashboardHeader._shortAddress(address);
        _pinLabel = shortName;
        _pinStreetName = shortName;
        _pinMoved = true;
      } else {
        _pinLabel = 'Aquí';
      }
    });
  }

  void _requestRide() {
    widget.onRequestRide(_currentPinPosition);
    _geocodeToken++;
    setState(() {
      _pinMoved = false;
      _currentPinPosition = null;
      _lastGeocodedPosition = null;
      _pinLabel = '';
      _pinStreetName = '';
    });
  }

  static BoxDecoration _floatingDecoration(double radius) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClientRideBloc, ClientRideState>(
      // La ubicación llegó después de crear el mapa: la cámara va a ella
      // si el pasajero aún no movió el mapa.
      listenWhen: (p, c) => p.originLatLng == null && c.originLatLng != null,
      listener: (context, state) {
        if (!_pinMoved) _centerOn(state.originLatLng);
      },
      buildWhen: (p, c) =>
          p.originLatLng != c.originLatLng || p.originName != c.originName,
      builder: (context, state) {
        final origin = state.originLatLng;
        final originName = state.originName?.trim() ?? '';
        final String topText;
        if (_pinStreetName.isNotEmpty) {
          topText = _pinStreetName;
        } else if (originName.isNotEmpty) {
          topText = originName;
        } else {
          topText = 'Detectando tu ubicación...';
        }
        return Stack(
          children: [
            // Mapa a pantalla completa. Sin marcadores propios: el punto
            // azul de Google marca la ubicación real y el pin, el recojo.
            Positioned.fill(
              child: GoogleMap(
                // Sin edificios 3D: al acercar se dibujan con lados sombreados
                // oscuros que rompen el estilo claro.
                buildingsEnabled: false,
                initialCameraPosition: CameraPosition(
                  target: origin ?? _fallbackCenter,
                  zoom: _zoom,
                ),
                style: _mapStyle,
                onMapCreated: (controller) => _mapController = controller,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false,
                markers: const {},
                onCameraMove: (position) {
                  // Se guarda sin reconstruir en cada frame del arrastre.
                  _currentPinPosition = position.target;
                },
                onCameraIdle: _onCameraIdle,
              ),
            ),

            // Pin fijo: su punta marca el centro exacto del mapa.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CenterPinPainter(
                    label: _pinLabel,
                    color: _kBlue,
                  ),
                ),
              ),
            ),

            // Barra superior con la dirección bajo el pin
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: _floatingDecoration(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.my_location_rounded,
                      color: _kBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        topText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kTextDark,
                        ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: resetPin,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF5FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.gps_fixed_rounded,
                          color: _kBlue,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // «Pedir taxi aquí»
            Positioned(
              bottom: 16,
              left: 24,
              right: 24,
              child: GestureDetector(
                onTap: _requestRide,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x550066CC),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Pedir taxi aquí',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Volver a mi ubicación
            Positioned(
              right: 16,
              bottom: 100,
              child: GestureDetector(
                onTap: resetPin,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: _kBlue,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// «Activar ubicación»: aparece en la cabecera cuando no se pudo leer el
/// GPS. Abre lo que haga falta (ajustes de ubicación si está apagada,
/// ajustes de la app si el permiso se negó para siempre) o vuelve a pedir
/// el permiso. Al regresar de ajustes, el dashboard reintenta solo.
class _EnableLocationLink extends StatelessWidget {
  const _EnableLocationLink();

  static const Color _orange = Color(0xFFFF6B35);

  Future<void> _enableLocation(BuildContext context) async {
    final rideBloc = context.read<ClientRideBloc>();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        return;
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }
    } catch (_) {
      // Si no se pudo consultar, se reintenta directamente.
    }
    // Permiso denegado una vez (o ya concedido): el bloc vuelve a pedirlo.
    rideBloc.add(const InitializePickupFromCurrentLocation());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _enableLocation(context),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_off_rounded, color: _orange, size: 12),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Activar ubicación',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: _orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera sobre el mapa libre: avatar, saludo y accesos.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onMenuTap});

  final VoidCallback onMenuTap;

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return '¡Buenos días,';
    if (hour >= 12 && hour < 19) return '¡Buenas tardes,';
    return '¡Buenas noches,';
  }

  /// Textos de respaldo del bloc cuando la geocodificación inversa falla:
  /// no son una dirección que mostrar.
  static const Set<String> _placeholderOriginNames = {
    'Mi ubicación actual',
    'Punto de recojo seleccionado',
  };

  /// Ubicación de la cabecera: la dirección del punto de recojo (GPS) en
  /// versión corta; la ciudad si hay coordenadas sin dirección; y mientras
  /// tanto, «Detectando ubicación...».
  static String _locationLabel(ClientRideState state) {
    final name = state.originName?.trim() ?? '';
    if (name.isNotEmpty && !_placeholderOriginNames.contains(name)) {
      return _shortAddress(name);
    }
    if (state.originLatLng != null) return 'Trujillo, Perú';
    return 'Detectando ubicación...';
  }

  /// Versión corta de una dirección de Google («Av. España 1234, Trujillo
  /// 13001, Perú» → «Av. España 1234, Trujillo»): la calle y, si es corta,
  /// la ciudad o distrito sin el código postal.
  static String _shortAddress(String fullAddress) {
    if (fullAddress.isEmpty) return 'Trujillo, Perú';

    final parts = fullAddress.split(',');
    final firstPart = parts.first.trim();

    if (firstPart.length > 30) {
      return '${firstPart.substring(0, 27)}...';
    }

    if (parts.length > 1) {
      final secondPart =
          parts[1].replaceAll(RegExp(r'\s*\d{4,}\s*'), ' ').trim();
      if (secondPart.isNotEmpty && secondPart.length < 20) {
        final combined = '$firstPart, $secondPart';
        if (combined.length <= 35) return combined;
      }
    }

    return firstPart;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 100 + topInset,
      child: Stack(
        children: [
          // El degradado no intercepta gestos: el mapa sigue siendo
          // arrastrable por debajo.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GenderAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, authState) {
                          if (authState is! AuthAuthenticated) {
                            return const Text(
                              '¡Bienvenido!',
                              style: TextStyle(
                                color: _kTextDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }
                          final firstName = authState.user.fullName
                              .trim()
                              .split(RegExp(r'\s+'))
                              .first;
                          return Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${_greeting()} ',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF666666),
                                  ),
                                ),
                                TextSpan(
                                  text: '$firstName!',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _kTextDark,
                                  ),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 2),
                      BlocBuilder<ClientRideBloc, ClientRideState>(
                        buildWhen: (p, c) =>
                            p.originName != c.originName ||
                            p.originLatLng != c.originLatLng ||
                            p.locationDenied != c.locationDenied,
                        builder: (context, rideState) {
                          // Sin GPS y sin un origen elegido a mano: se
                          // ofrece activarlo.
                          if (rideState.locationDenied &&
                              rideState.originLatLng == null) {
                            return const _EnableLocationLink();
                          }
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: _kBlue,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  _locationLabel(rideState),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _kBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: _kTextDark,
                    size: 24,
                  ),
                  // TODO: notificaciones.
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: _kTextDark,
                    size: 24,
                  ),
                  tooltip: 'Menú',
                  onPressed: onMenuTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderAvatar extends StatelessWidget {
  const _GenderAvatar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final gender = state is AuthAuthenticated
            ? (state.user.gender ?? 'other')
            : 'other';
        final Color background;
        final Color foreground;
        final IconData icon;
        switch (gender) {
          case 'male':
            background = const Color(0xFFE3F2FD);
            foreground = const Color(0xFF1565C0);
            icon = Icons.person_rounded;
          case 'female':
            background = const Color(0xFFFCE4EC);
            foreground = const Color(0xFFC2185B);
            icon = Icons.person_2_rounded;
          default:
            background = const Color(0xFFE8F5E9);
            foreground = const Color(0xFF2E7D32);
            icon = Icons.person_outline_rounded;
        }
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: background,
            border: Border.all(color: _kBlue, width: 2),
          ),
          child: Icon(icon, color: foreground, size: 24),
        );
      },
    );
  }
}

/// Inicio del dashboard (sin mapa): cabecera, buscador, cuadrícula de
/// vehículos y banner. Solo se muestra con el flujo en reposo; al buscar
/// destino lo reemplaza el mapa con sus paneles.
class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.onMenuTap,
    required this.onSearchTap,
    required this.onCategoryConfirmed,
  });

  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final ValueChanged<ClientVehicleCategory> onCategoryConfirmed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DashboardHeader(onMenuTap: onMenuTap),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlocBuilder<ClientRideBloc, ClientRideState>(
                  buildWhen: (p, c) =>
                      p.status != c.status || p.errorMessage != c.errorMessage,
                  builder: (context, state) {
                    if (state.status != ClientRideStatus.error ||
                        state.errorMessage == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.errorRed,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
                _SearchBar(onTap: onSearchTap),
                const SizedBox(height: 20),
                _VehicleSection(onCategoryConfirmed: onCategoryConfirmed),
                const SizedBox(height: 20),
                const _PromoBanner(),
                const _TopDriversSection(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: _kBlue, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¿A dónde vas?',
                style: TextStyle(color: Color(0xFF999999), fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF5FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, color: _kBlue, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Ahora',
                    style: TextStyle(
                      color: _kBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuadrícula 2x2 de vehículos. Tocar una tarjeta elige la categoría y pasa
/// a la búsqueda de destino.
class _VehicleSection extends StatelessWidget {
  const _VehicleSection({required this.onCategoryConfirmed});

  final ValueChanged<ClientVehicleCategory> onCategoryConfirmed;

  /// Distancia de referencia para el precio «Desde» de cada tarjeta.
  static const double _referenceKm = 3.0;

  static double _referencePrice(ClientVehicleCategory category) {
    return ClientRidePricing.totalSuggested(
      routeBase: ClientRidePricing.routeBaseFromDistanceKm(_referenceKm),
      category: category,
      moreThanFourPassengers: false,
      babySeat: false,
      pet: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Elige tu vehículo',
              style: TextStyle(
                color: _kTextDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${kVehicleCategoryOptions.length} disponibles',
              style: const TextStyle(
                color: _kBlue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Todas las tarjetas se ven igual: la categoría elegida no se marca.
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Sin el padding que GridView toma de MediaQuery, y sin recorte
          // para no cortar las sombras de las tarjetas.
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            for (final option in kVehicleCategoryOptions)
              VehicleCategoryCard(
                option: option,
                priceLabel: 'Desde S/ '
                    '${_referencePrice(option.category).toStringAsFixed(1)}',
                onTap: () => onCategoryConfirmed(option.category),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Lleva Trujillo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '¡Bienvenido a Lleva!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tarifas justas para\ntodos en Trujillo.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Hueco reservado para una imagen (Image.asset) cuando existan
          // los assets; por ahora muestra un ícono.
          Expanded(
            flex: 2,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.directions_car_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de conductores destacados bajo el banner. Si no hay conductores (o
/// la vista `top_drivers` no está disponible) muestra uno de muestra.
class _TopDriversSection extends StatelessWidget {
  const _TopDriversSection();

  /// Conductor de muestra (datos ficticios) que se enseña cuando la vista
  /// `top_drivers` no devuelve ninguno.
  static const TopDriverEntity _defaultDriver = TopDriverEntity(
    id: 'default',
    fullName: 'Carlos Rodríguez',
    profilePicUrl: null,
    carBrand: 'Toyota',
    carModel: 'Corolla',
    carColor: 'Blanco',
    carYear: 2022,
    driverRating: 4.9,
    tripCount: 248,
  );

  static const TextStyle _titleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: _kTextDark,
  );

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TopDriversCubit, TopDriversState>(
      builder: (context, state) {
        if (state is TopDriversLoading) {
          return _buildLoadingDrivers();
        }
        if (state is TopDriversLoaded) {
          return _buildDriversList(
            state.drivers.isEmpty ? const [_defaultDriver] : state.drivers,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingDrivers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Conductores estrella ⭐', style: _titleStyle),
            const Spacer(),
            Container(
              width: 60,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Tarjetas de relleno mientras carga
        for (int i = 0; i < 3; i++)
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
      ],
    );
  }

  Widget _buildDriversList(List<TopDriverEntity> drivers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Conductores estrella ⭐', style: _titleStyle),
            const Spacer(),
            Text(
              '${drivers.length} disponibles',
              style: const TextStyle(
                fontSize: 12,
                color: _kBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...drivers.map((driver) => _DriverCard(driver: driver)),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final TopDriverEntity driver;

  /// Nombre y primer apellido.
  String get _shortName {
    final parts = driver.fullName.trim().split(RegExp(r'\s+'));
    return parts.take(2).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    const fallbackAvatar = Icon(Icons.person_rounded, color: _kBlue, size: 28);
    final car = '${driver.carBrand ?? ''} ${driver.carModel ?? ''}'.trim();
    final photoUrl = driver.profilePicUrl?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEEF5FF),
              border: Border.all(color: _kBlue, width: 1.5),
            ),
            child: photoUrl.isEmpty
                ? fallbackAvatar
                : ClipOval(
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => fallbackAvatar,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Datos del conductor
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB800).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '⭐ Top conductor',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB8860B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  car,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (i) => Icon(
                        i < driver.driverRating.round()
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB800),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      driver.driverRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFCCCCCC),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Va justo en pantallas angostas: se corta antes que
                    // desbordar.
                    Flexible(
                      child: Text(
                        '${driver.tripCount} viajes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Vehículo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              size: 32,
              color: _kBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTabBar extends StatelessWidget {
  const _DashboardTabBar({
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
            _TabItem(
              icon: Icons.home_rounded,
              label: 'Inicio',
              isSelected: currentTab == 0,
              onTap: onHomeTap,
            ),
            _TabItem(
              icon: Icons.map_rounded,
              label: 'Mapa',
              isSelected: currentTab == 1,
              onTap: onMapTap,
            ),
            _TabItem(
              icon: Icons.headset_mic_rounded,
              label: 'Soporte',
              isSelected: currentTab == 2,
              onTap: onSupportTap,
            ),
            _TabItem(
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

class _TabItem extends StatelessWidget {
  const _TabItem({
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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

/// Búsqueda de destino a pantalla completa sobre el mapa.
///
/// - [_SearchStep.mapWithOrigin]: mapa interactivo (se puede ajustar el punto
///   de recojo), cabecera con los pasos y panel inferior con origen y destino.
/// - [_SearchStep.searchingDestination]: el mismo mapa, difuminado, con el
///   buscador encima.
///
/// El mapa es siempre el primer hijo y lleva [mapLayerKey]: así no se
/// recrea al cambiar de paso.
class _SearchFlowView extends StatefulWidget {
  const _SearchFlowView({
    required this.step,
    required this.mapLayerKey,
    required this.mapGestureActiveNotifier,
    required this.searchPulseController,
    required this.originFocusNode,
    required this.destFocusNode,
    required this.searchController,
    required this.recentDestinations,
    required this.onBack,
    required this.editingField,
    required this.onCancelEditing,
    required this.onSearchDestination,
    required this.onOriginFieldTap,
    required this.onDestinationFieldTap,
    required this.onContinue,
    required this.onQueryChanged,
    required this.isLoadingResults,
    required this.onTypedDestinationSelected,
    required this.onPopularTap,
    required this.onRecentSelected,
    required this.onSuggestionSelected,
    required this.onPredictionSelected,
    required this.onPinConfirmed,
  });

  final _SearchStep step;
  final GlobalKey mapLayerKey;
  final ValueNotifier<bool> mapGestureActiveNotifier;
  final AnimationController searchPulseController;
  final FocusNode originFocusNode;
  final FocusNode destFocusNode;
  final TextEditingController searchController;
  final List<String> recentDestinations;
  final VoidCallback onBack;
  final _EditingField editingField;
  final VoidCallback onCancelEditing;

  /// Abre el buscador de destino (desde el aviso de edición del destino).
  final VoidCallback onSearchDestination;
  final VoidCallback onOriginFieldTap;
  final VoidCallback onDestinationFieldTap;
  final VoidCallback onContinue;
  final ValueChanged<String> onQueryChanged;
  final bool isLoadingResults;
  final ValueChanged<String> onTypedDestinationSelected;
  final VoidCallback onPopularTap;
  final ValueChanged<String> onRecentSelected;
  final ValueChanged<_Place> onSuggestionSelected;
  final ValueChanged<Prediction> onPredictionSelected;
  final void Function(LatLng position, String label) onPinConfirmed;

  @override
  State<_SearchFlowView> createState() => _SearchFlowViewState();
}

class _SearchFlowViewState extends State<_SearchFlowView> {
  /// Alto real de la cabecera flotante y del panel de origen/destino,
  /// medidos tras dibujarlos: el mapa encuadra la ruta entre ambos.
  double _headerHeight = 0;
  double _panelHeight = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final mapLayerKey = widget.mapLayerKey;
    final editingField = widget.editingField;
    final editing = editingField != _EditingField.none;
    final onBack = widget.onBack;
    final searching = step == _SearchStep.searchingDestination;
    // Con la ruta ya definida el mapa deja de fijar el recojo con el pin
    // central: muestra origen, destino y ruta, y arrastrarlo no los cambia.
    final hasRoute = context.select<ClientRideBloc, bool>(
      (bloc) =>
          bloc.state.originLatLng != null && bloc.state.destLatLng != null,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final topInset = MediaQuery.paddingOf(context).top;
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return Stack(
          fit: StackFit.expand,
          children: [
            // El mapa de origen/destino sigue montado (oculto) mientras se
            // elige el destino: al volver no se recrea.
            Positioned.fill(
              key: mapLayerKey,
              child: Offstage(
                offstage: searching,
                child: ClientMapLayer(
                  mapGestureActiveNotifier: widget.mapGestureActiveNotifier,
                  searchPulseController: widget.searchPulseController,
                  originFocusNode: widget.originFocusNode,
                  destFocusNode: widget.destFocusNode,
                  allowPinSelection: !hasRoute || editing,
                  editDestination: editingField == _EditingField.destination,
                  // Origen y destino se encuadran entre la cabecera y el
                  // panel inferior, no detrás de ellos.
                  routePadding: EdgeInsets.only(
                    top: topInset + 8 + _headerHeight,
                    bottom: bottomInset + 12 + _panelHeight,
                  ),
                ),
              ),
            ),
            // Elegir destino: mapa propio con el pin rojo y la barra de
            // búsqueda abajo.
            if (searching)
              Positioned.fill(
                child: _DestinationPickerView(
                  searchController: widget.searchController,
                  recentDestinations: widget.recentDestinations,
                  isLoadingResults: widget.isLoadingResults,
                  onQueryChanged: widget.onQueryChanged,
                  onTypedDestinationSelected:
                      widget.onTypedDestinationSelected,
                  onPopularTap: widget.onPopularTap,
                  onRecentSelected: widget.onRecentSelected,
                  onSuggestionSelected: widget.onSuggestionSelected,
                  onPredictionSelected: widget.onPredictionSelected,
                  onPinConfirmed: widget.onPinConfirmed,
                ),
              ),
            // Cabecera flotante: visible en los dos pasos.
            Positioned(
              top: topInset + 8,
              left: 16,
              right: 16,
              child: _SizeReporter(
                onHeight: (h) => _updateHeights(header: h),
                child: _SearchStepsHeader(onBack: onBack),
              ),
            ),
            // Editando origen o destino: aviso bajo la cabecera.
            if (!searching && editing)
              Positioned(
                top: topInset + 8 + _headerHeight + 10,
                left: 24,
                right: 24,
                child: Center(
                  child: _EditingHint(
                    field: editingField,
                    onSearch: widget.onSearchDestination,
                    onCancel: widget.onCancelEditing,
                  ),
                ),
              ),
            if (!searching)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 12,
                child: _SizeReporter(
                  onHeight: (h) => _updateHeights(panel: h),
                  child: _OriginDestinationPanel(
                    onOriginTap: widget.onOriginFieldTap,
                    onDestinationTap: widget.onDestinationFieldTap,
                    onContinue: widget.onContinue,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _updateHeights({double? header, double? panel}) {
    final nextHeader = header ?? _headerHeight;
    final nextPanel = panel ?? _panelHeight;
    if ((nextHeader - _headerHeight).abs() < 1 &&
        (nextPanel - _panelHeight).abs() < 1) {
      return;
    }
    setState(() {
      _headerHeight = nextHeader;
      _panelHeight = nextPanel;
    });
  }
}

/// Aviso flotante mientras se cambia el origen o el destino con el pin: qué
/// hacer y, para el destino, un acceso al buscador. La X cancela.
class _EditingHint extends StatelessWidget {
  const _EditingHint({
    required this.field,
    required this.onSearch,
    required this.onCancel,
  });

  final _EditingField field;
  final VoidCallback onSearch;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final isDest = field == _EditingField.destination;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              isDest
                  ? 'Mueve el pin para cambiar el destino'
                  : 'Mueve el pin para cambiar el origen',
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (isDest) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: onSearch,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Buscar',
                style: TextStyle(
                  color: _kBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          IconButton(
            onPressed: onCancel,
            tooltip: 'Cancelar',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFF888888),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avisa el alto de [child] tras cada frame en que cambia.
class _SizeReporter extends StatefulWidget {
  const _SizeReporter({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_SizeReporter> createState() => _SizeReporterState();
}

class _SizeReporterState extends State<_SizeReporter> {
  double? _lastHeight;

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final height = box.size.height;
      if (_lastHeight != null && (height - _lastHeight!).abs() < 1) return;
      _lastHeight = height;
      widget.onHeight(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _report();
    return widget.child;
  }
}

/// Cabecera flotante de la búsqueda: volver + pasos.
class _SearchStepsHeader extends StatelessWidget {
  const _SearchStepsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _kTextDark,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Row(
              children: [
                RideStepIndicator(number: 1, label: 'Destino', isActive: true),
                RideStepDivider(),
                RideStepIndicator(number: 2, label: 'Pago', isActive: false),
                RideStepDivider(),
                RideStepIndicator(number: 3, label: 'Vehículo', isActive: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel inferior del paso «mapa con origen»: origen (solo lectura, se
/// ajusta moviendo el mapa), destino (abre el buscador) y, cuando ya hay
/// ruta, el botón para continuar a la tarifa.
class _OriginDestinationPanel extends StatelessWidget {
  const _OriginDestinationPanel({
    required this.onOriginTap,
    required this.onDestinationTap,
    required this.onContinue,
  });

  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;
  final VoidCallback onContinue;

  static const Color _originGreen = Color(0xFF00AA44);
  static const TextStyle _labelStyle = TextStyle(
    fontSize: 11,
    color: Color(0xFF888888),
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BlocBuilder<ClientRideBloc, ClientRideState>(
        builder: (context, state) {
          final originName = state.originName?.trim() ?? '';
          final hasOrigin = originName.isNotEmpty;
          // El destino cuenta como elegido solo si ya tiene coordenadas
          // (destName también guarda lo que se va escribiendo).
          final destName = state.destName?.trim() ?? '';
          final hasDest = state.destLatLng != null && destName.isNotEmpty;
          final hasDestCoords = state.destLatLng != null;
          final canContinue = state.originLatLng != null && hasDestCoords;
          // Con destino fijado, las dos filas llevan un lápiz: se pueden
          // tocar para editarlas.
          const editIcon = Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.edit_rounded,
              color: Color(0xFFCCCCCC),
              size: 14,
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status == ClientRideStatus.error &&
                  state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Origen: se cambia moviendo el mapa (tocar la fila lo indica
              // y, si ya hay ruta, reactiva el pin de recojo).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onOriginTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: _originGreen,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Origen', style: _labelStyle),
                            Text(
                              hasOrigin
                                  ? originName.split('\n').first
                                  : 'Detectando ubicación...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hasOrigin
                                    ? _kTextDark
                                    : const Color(0xFF999999),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasDestCoords) editIcon,
                    ],
                  ),
                ),
              ),

              // Conector entre origen y destino + botón para intercambiarlos
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 36,
                      child: Center(
                        child: SizedBox(
                          width: 1.5,
                          height: 24,
                          child: ColoredBox(color: Color(0xFFDDDDDD)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: Color(0xFFF0F0F0)),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Solo intercambia cuando hay origen y destino.
                      onTap: canContinue
                          ? () => context
                              .read<ClientRideBloc>()
                              .add(const SwapOriginDestination())
                          : null,
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.swap_vert_rounded,
                          color: canContinue ? _kBlue : const Color(0xFFBBBBBB),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Destino: toda la fila abre el buscador
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDestinationTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF5FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: _kBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Destino', style: _labelStyle),
                            Text(
                              hasDest
                                  ? destName.split('\n').first
                                  : '¿A dónde vas?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hasDest ? _kTextDark : _kBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasDestCoords) editIcon,
                    ],
                  ),
                ),
              ),

              // Destino sin punto exacto (texto libre o Places sin
              // coordenadas): está en el centro de Trujillo, y la distancia
              // y la tarifa se calculan hasta ahí. Se avisa al pasajero.
              if (state.destLatLng == ClientRideBloc.fallbackDestLatLng) ...[
                const SizedBox(height: 6),
                const Text(
                  'Ubicación aproximada: centro de Trujillo. La distancia y '
                  'la tarifa pueden variar; indica el punto exacto al '
                  'conductor.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: AppTheme.warningOrange,
                  ),
                ),
              ],
              // Sin destino: botón para buscarlo. Con destino desaparece (la
              // fila de destino sigue abriendo el buscador).
              if (!hasDestCoords) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onDestinationTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _kBlue.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_rounded, color: _kBlue, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Buscar destino',
                          style: TextStyle(
                            color: _kBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Con destino: resumen del viaje (la oferta se ajusta en los
              // pasos de pago y vehículo).
              if (hasDestCoords) ...[
                const SizedBox(height: 12),
                _TripSummary(state: state),
              ],
              if (canContinue) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onContinue,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x440066CC),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continuar al pago',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Resumen del viaje en el panel de origen/destino: distancia y duración (la
/// tarifa va aparte, en RidePriceControl). Muestra guiones mientras la ruta
/// se calcula.
class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.state});

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    const divider = SizedBox(
      width: 1,
      height: 28,
      child: ColoredBox(color: Color(0xFFE0E0E0)),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TripInfoChip(
            icon: Icons.route_rounded,
            label: RideTripLabels.distance(state),
            color: _kBlue,
          ),
          divider,
          _TripInfoChip(
            icon: Icons.access_time_rounded,
            label: RideTripLabels.duration(state),
            color: _kBlue,
          ),
        ],
      ),
    );
  }
}

class _TripInfoChip extends StatelessWidget {
  const _TripInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _kTextDark,
          ),
        ),
      ],
    );
  }
}

/// Estilo claro de los mapas, leído una sola vez y compartido.
String? _lightMapStyleCache;

Future<String?> _loadLightMapStyle() async {
  if (_lightMapStyleCache != null) return _lightMapStyleCache;
  try {
    _lightMapStyleCache = await rootBundle.loadString('assets/map_style.json');
  } catch (_) {
    // Sin estilo: queda el mapa por defecto.
  }
  return _lightMapStyleCache;
}

/// Paso «buscar destino»: mapa completo con un pin rojo fijo en el centro
/// (se mueve el mapa para colocarlo; su etiqueta muestra la calle) y, abajo,
/// una barra compacta para buscar por nombre o confirmar el punto del pin.
class _DestinationPickerView extends StatefulWidget {
  const _DestinationPickerView({
    required this.searchController,
    required this.recentDestinations,
    required this.isLoadingResults,
    required this.onQueryChanged,
    required this.onTypedDestinationSelected,
    required this.onPopularTap,
    required this.onRecentSelected,
    required this.onSuggestionSelected,
    required this.onPredictionSelected,
    required this.onPinConfirmed,
  });

  final TextEditingController searchController;
  final List<String> recentDestinations;
  final bool isLoadingResults;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTypedDestinationSelected;
  final VoidCallback onPopularTap;
  final ValueChanged<String> onRecentSelected;
  final ValueChanged<_Place> onSuggestionSelected;
  final ValueChanged<Prediction> onPredictionSelected;

  /// «Confirmar destino aquí»: punto bajo el pin y su calle.
  final void Function(LatLng position, String label) onPinConfirmed;

  @override
  State<_DestinationPickerView> createState() =>
      _DestinationPickerViewState();
}

class _DestinationPickerViewState extends State<_DestinationPickerView> {
  static const LatLng _fallbackCenter = LatLng(-8.1091, -79.0215);
  static const double _zoom = 15;
  static const double _regeocodeMeters = 10;
  static const Color _destRed = CustomMapMarkers.destPinColor;

  /// Ícono del pin azul de origen, generado una vez.
  static Future<BitmapDescriptor>? _originPinFuture;

  GoogleMapController? _destMapController;
  String? _mapStyle = _lightMapStyleCache;
  BitmapDescriptor? _originPinIcon;
  final FocusNode _searchFocus = FocusNode();

  /// Centro de la cámara (punta del pin) y calle bajo el pin.
  LatLng? _destPinPosition;
  String _destPinLabel = '';
  LatLng? _lastGeocodedPosition;
  int _geocodeToken = 0;

  /// true si el texto del buscador lo puso el pin (calle bajo el pin) y no
  /// el pasajero: no se muestran resultados para ese texto.
  bool _searchTextFromPin = false;

  @override
  void initState() {
    super.initState();
    if (_mapStyle == null) {
      _loadLightMapStyle().then((style) {
        if (mounted && style != null) setState(() => _mapStyle = style);
      });
    }
    _originPinFuture ??= CustomMapMarkers.createPinMarker();
    _originPinFuture!.then((icon) {
      if (mounted) setState(() => _originPinIcon = icon);
    }).catchError((_) {});
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _destMapController?.dispose();
    super.dispose();
  }

  Future<void> _onCameraIdle() async {
    final position = _destPinPosition;
    if (position == null) return;
    final last = _lastGeocodedPosition;
    if (last != null &&
        Geolocator.distanceBetween(
              last.latitude,
              last.longitude,
              position.latitude,
              position.longitude,
            ) <
            _regeocodeMeters) {
      return;
    }
    _lastGeocodedPosition = position;
    final token = ++_geocodeToken;
    setState(() => _destPinLabel = CenterPinPainter.loadingLabel);

    String? address;
    try {
      address = await di.sl<PlacesService>().reverseGeocode(position);
    } catch (_) {
      address = null;
    }
    if (!mounted || token != _geocodeToken) return;
    setState(() {
      if (address != null) {
        final short = _DashboardHeader._shortAddress(address);
        _destPinLabel = short;
        // El buscador muestra también la calle del pin (sin abrir la lista
        // de resultados: no la escribió el pasajero).
        _searchTextFromPin = true;
        widget.searchController.value = TextEditingValue(
          text: short,
          selection: TextSelection.collapsed(offset: short.length),
        );
      } else {
        _destPinLabel = 'Aquí';
      }
    });
  }

  /// Nombre con que se guarda el destino del pin.
  String get _confirmName {
    final label = _destPinLabel.trim();
    if (label.isEmpty ||
        label == CenterPinPainter.loadingLabel ||
        label == 'Aquí') {
      return 'Destino seleccionado en el mapa';
    }
    return label;
  }

  void _confirmPin() {
    final position = _destPinPosition;
    if (position == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onPinConfirmed(position, _confirmName);
  }

  @override
  Widget build(BuildContext context) {
    final rideState = context.watch<ClientRideBloc>().state;
    final origin = rideState.originLatLng;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final canConfirm = _destPinPosition != null;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            // Sin edificios 3D: al acercar se dibujan con lados sombreados
            // oscuros que rompen el estilo claro.
            buildingsEnabled: false,
            initialCameraPosition: CameraPosition(
              // Si ya había destino se parte de él; si no, del origen.
              target: rideState.destLatLng ?? origin ?? _fallbackCenter,
              zoom: _zoom,
            ),
            style: _mapStyle,
            onMapCreated: (controller) => _destMapController = controller,
            markers: {
              if (origin != null)
                Marker(
                  markerId: const MarkerId('origin'),
                  position: origin,
                  icon: _originPinIcon ??
                      BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                  anchor: const Offset(0.5, 1.0),
                ),
            },
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            onTap: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            onCameraMove: (position) => _destPinPosition = position.target,
            onCameraIdle: _onCameraIdle,
          ),
        ),

        // Pin rojo de destino: la punta marca el centro exacto del mapa.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: CenterPinPainter(
                label: _destPinLabel,
                color: _destRed,
              ),
            ),
          ),
        ),

        // Barra inferior: buscar por nombre o confirmar el pin. Sube con el
        // teclado (el Scaffold no se redimensiona en este paso).
        Positioned(
          left: 0,
          right: 0,
          bottom: keyboard,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              (keyboard > 0 ? 0 : safeBottom) + 14,
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
                const SizedBox(height: 12),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: TextField(
                    controller: widget.searchController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 14, color: _kTextDark),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      hintText: 'Buscar destino...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _kBlue,
                        size: 18,
                      ),
                      suffixIcon: widget.searchController.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchTextFromPin = false;
                                widget.searchController.clear();
                                widget.onQueryChanged('');
                                setState(() {});
                              },
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFF999999),
                                size: 18,
                              ),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      _searchTextFromPin = false;
                      setState(() {});
                      widget.onQueryChanged(value);
                    },
                  ),
                ),
                _buildResults(rideState),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: canConfirm ? _confirmPin : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: canConfirm
                          ? const LinearGradient(
                              colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            )
                          : null,
                      color: canConfirm ? null : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          color: canConfirm
                              ? Colors.white
                              : const Color(0xFF999999),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          canConfirm
                              ? 'Confirmar destino aquí'
                              : 'Mueve el mapa para marcar tu destino',
                          style: TextStyle(
                            color: canConfirm
                                ? Colors.white
                                : const Color(0xFF999999),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Resultados bajo el buscador. Con [_kMinSearchChars] o más caracteres:
  /// lugares sugeridos que coinciden y resultados de Places. Con el campo
  /// vacío y enfocado: destinos recientes (o el concurrido).
  Widget _buildResults(ClientRideState state) {
    // Texto puesto por el pin: no es una búsqueda.
    if (_searchTextFromPin) return const SizedBox.shrink();
    final query = widget.searchController.text.trim();
    final tiles = <Widget>[];

    if (query.length >= _kMinSearchChars) {
      final lower = query.toLowerCase();
      final local = _kTrujilloSuggestions
          .where(
            (p) =>
                p.name.toLowerCase().contains(lower) ||
                p.address.toLowerCase().contains(lower),
          )
          .take(3);
      for (final place in local) {
        tiles.add(
          _DestinationTile(
            icon: Icons.place_rounded,
            iconColor: _destRed,
            title: place.name,
            subtitle: place.address,
            onTap: () => widget.onSuggestionSelected(place),
          ),
        );
      }
      for (final prediction in state.destPredictions) {
        tiles.add(
          _DestinationTile(
            icon: Icons.location_on_rounded,
            iconColor: _destRed,
            title: prediction.description,
            onTap: () => widget.onPredictionSelected(prediction),
          ),
        );
      }
      if (tiles.isEmpty) {
        if (widget.isLoadingResults) {
          tiles.add(
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kBlue,
                  ),
                ),
              ),
            ),
          );
        } else {
          tiles.add(
            _DestinationTile(
              icon: Icons.edit_location_alt_rounded,
              iconColor: const Color(0xFF888888),
              title: 'Usar «$query»',
              subtitle: 'Sin resultados: ubicación aproximada. '
                  'También puedes mover el mapa.',
              onTap: () => widget.onTypedDestinationSelected(query),
            ),
          );
        }
      }
    } else if (_searchFocus.hasFocus && query.isEmpty) {
      if (widget.recentDestinations.isNotEmpty) {
        for (final name in widget.recentDestinations.take(3)) {
          tiles.add(
            _DestinationTile(
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF888888),
              title: name,
              onTap: () => widget.onRecentSelected(name),
            ),
          );
        }
      } else {
        tiles.add(
          _DestinationTile(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF6B35),
            title: _kPopularDestinations.first.name,
            subtitle: _kPopularDestinations.first.address,
            onTap: widget.onPopularTap,
          ),
        );
      }
    }

    if (tiles.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 8),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: tiles,
      ),
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _kTextDark,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF888888),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFCCCCCC),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
