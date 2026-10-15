import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../../core/enums/client_ride_status.dart';
import '../../../core/enums/client_vehicle_category.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/client_ride_pricing.dart';
import '../../../domain/entities/ride_entity.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import '../../widgets/client/driver_offer_panel.dart';
import '../../widgets/client/driver_on_the_way_panel.dart';
import '../../widgets/client/route_preview_map.dart';
import '../../widgets/client/vehicle_category_card.dart';
import 'ride_flow_routes.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);
const Color _kCancelRed = Color(0xFFFF4444);
const Color _kLiveGreen = Color(0xFF00CC44);

/// Demostración: conductores de muestra en el mapa y una oferta simulada.
/// Son datos ficticios, sin relación con conductores reales; poner en
/// `false` para desactivarlos (las ofertas reales siguen funcionando).
const bool _kShowDemoDrivers = true;

/// Momento en que el primer conductor de muestra «envía» su oferta.
const Duration _kDemoOfferDelay = Duration(seconds: 30);

/// Tras rechazar una oferta de muestra, lo que tarda en llegar la del
/// siguiente conductor.
const Duration _kDemoNextOfferDelay = Duration(seconds: 8);

/// Lo que dura en pantalla el trayecto simulado del conductor aceptado
/// hasta el punto de recojo (más corto que su tiempo de llegada).
const Duration _kDemoTripDuration = Duration(seconds: 45);

/// Tiempo que el conductor espera al pasajero una vez que llegó.
const Duration _kDriverWaitDuration = Duration(minutes: 5);

/// Tras este tiempo buscando conductor se puede ajustar la oferta.
const Duration _kPriceControlsDelay = Duration(seconds: 20);

/// Una solicitud que nadie acepta en este tiempo se cancela sola.
const Duration _kSearchTimeout = Duration(minutes: 15);

/// Estimación del tiempo de llegada del conductor real a partir de su
/// distancia en línea recta: rodeo medio por calles y velocidad en ciudad.
const double _kRoadFactor = 1.3;
const double _kCitySpeedKmh = 25;

/// Zoom del mapa cuando el conductor ya llegó; durante su trayecto se
/// acerca poco a poco desde [RoutePreviewMap.defaultOriginZoom] hasta aquí.
const double _kArrivedZoom = 17.5;

/// Pasos en que se reparte ese acercamiento.
const int _kZoomSteps = 12;

/// Distancia (px) a la que el conductor se detiene junto al punto de
/// recojo, para que al llegar se vean los dos: él y la ubicación del
/// pasajero.
const double _kArrivedDistance = 52;

/// Conductor de muestra: dónde se dibuja respecto al punto de origen (en
/// píxeles de pantalla), cuándo aparece y sus datos para la oferta.
class _DemoDriver {
  const _DemoDriver({
    required this.offset,
    required this.appearsAfter,
    required this.etaMinutes,
    required this.name,
    required this.rating,
    required this.completedTrips,
    required this.plate,
    required this.counterOfferDelta,
  });

  final Offset offset;
  final Duration appearsAfter;
  final int etaMinutes;
  final String name;
  final double rating;
  final int completedTrips;
  final String plate;

  /// Cuánto sube su contraoferta sobre el precio del pasajero (S/).
  final double counterOfferDelta;
}

const List<_DemoDriver> _kDemoDrivers = [
  _DemoDriver(
    offset: Offset(-96, -58),
    appearsAfter: Duration(seconds: 2),
    etaMinutes: 3,
    name: 'Carlos Rodríguez',
    rating: 4.9,
    completedTrips: 248,
    plate: 'T1A-234',
    counterOfferDelta: 1.5,
  ),
  _DemoDriver(
    offset: Offset(104, -26),
    appearsAfter: Duration(seconds: 6),
    etaMinutes: 5,
    name: 'María Torres',
    rating: 4.8,
    completedTrips: 176,
    plate: 'T2B-518',
    counterOfferDelta: 0.5,
  ),
  _DemoDriver(
    offset: Offset(-34, 86),
    appearsAfter: Duration(seconds: 10),
    etaMinutes: 7,
    name: 'Luis Paredes',
    rating: 4.7,
    completedTrips: 132,
    plate: 'T3C-907',
    counterOfferDelta: 1.0,
  ),
];

/// Viaje de muestra en curso: el conductor aceptado va hacia el pasajero.
class _DemoTrip {
  const _DemoTrip({
    required this.driverIndex,
    required this.carModel,
    required this.amount,
    required this.vehicle,
  });

  final int driverIndex;
  final String carModel;
  final double amount;
  final VehicleCategoryOption vehicle;

  _DemoDriver get driver => _kDemoDrivers[driverIndex];
}

/// Pantalla completa del viaje del pasajero, de la búsqueda de conductor
/// al final del trayecto. La abre el dashboard en cuanto hay una solicitud
/// o un viaje activo (también al reabrir la app). Espera un
/// [ClientRideBloc] ya provisto por quien navega aquí.
///
/// - Buscando: mapa centrado en el punto de origen (con ondas que laten a
///   su alrededor), cabecera con el mensaje de estado y panel inferior con
///   el vehículo, la oferta y los conductores que la están viendo. Cuando
///   un conductor envía una oferta, el panel cambia a [DriverOfferPanel].
/// - Conductor asignado, llegó y viaje en curso: [DriverOnTheWayPanel] con
///   los datos del conductor y su posición en el mapa.
/// - Viaje terminado: resumen con el total.
///
/// Se cierra sola (junto con los pasos de pago y vehículo) cuando ya no
/// hay viaje: cancelación, error al pedirlo o resumen final cerrado.
class SearchingDriverScreen extends StatefulWidget {
  const SearchingDriverScreen({super.key});

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen>
    with TickerProviderStateMixin {
  static const List<String> _searchMessages = [
    'Estamos buscando conductores...',
    'Enviando tu oferta a conductores cercanos...',
    'Conductores revisando tu solicitud...',
    'Encontrando el mejor conductor para ti...',
    'Casi listo, esperando respuesta...',
  ];

  /// Separación de la cabecera flotante respecto a la barra de estado.
  static const double _headerTopMargin = 12;
  static const double _headerHeight = 76;

  /// Marca las ondas del punto de origen (0→1 en bucle).
  late final AnimationController _controller;
  Timer? _messageTimer;

  /// A los [_kPriceControlsDelay] de búsqueda aparecen los botones para
  /// ajustar la oferta.
  Timer? _priceControlTimer;
  bool _showPriceControls = false;
  int _messageIndex = 0;

  /// Alto real del panel inferior, medido tras dibujarlo. El valor inicial
  /// es solo una aproximación para el primer frame.
  final GlobalKey _bottomPanelKey = GlobalKey();
  double _bottomPanelHeight = 330;

  /// Cambia para pedirle al mapa que vuelva a centrarse en el origen.
  int _recenterToken = 0;

  /// true mientras se procesa la aceptación de una oferta real.
  bool _acceptingOffer = false;

  // ── Demostración ([_kShowDemoDrivers]) ──
  final List<Timer> _demoTimers = [];

  /// Cuántos conductores de muestra se ven ya en el mapa.
  int _visibleDemoDrivers = 0;

  /// Índice del conductor de muestra cuya oferta está en pantalla.
  int? _demoOfferDriver;
  DriverOfferView? _demoOffer;

  /// Viaje de muestra tras aceptar una oferta: el conductor va hacia el
  /// pasajero. [_tripController] marca su avance (0→1).
  _DemoTrip? _demoTrip;
  late final AnimationController _tripController;

  /// Paso actual del acercamiento del mapa (0.._kZoomSteps).
  int _zoomStep = 0;

  /// Espera del conductor tras llegar: cuenta regresiva por segundos.
  Timer? _waitTimer;
  Duration _waitRemaining = _kDriverWaitDuration;

  /// true si el pasajero ya avisó «Ya voy».
  bool _comingAnnounced = false;

  // ── Viaje real ──
  /// Mayor distancia (m) vista entre el conductor y el punto de recojo, y
  /// entre el conductor y el destino: el 0 % de cada barra de avance.
  double? _pickupStartMeters;
  double? _tripStartMeters;

  /// Último error ya avisado, para no repetirlo.
  String? _lastShownError;

  /// true si la solicitud ya se canceló por [_kSearchTimeout].
  bool _searchTimedOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _tripController = AnimationController(
      vsync: this,
      duration: _kDemoTripDuration,
    )
      ..addListener(_onTripTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _startWaitCountdown();
      });
    _priceControlTimer = Timer(_kPriceControlsDelay, () {
      if (mounted) setState(() => _showPriceControls = true);
    });
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _searchMessages.length;
      });
      _checkSearchTimeout();
    });
    // La demostración es solo de la búsqueda: no arranca si la pantalla se
    // abre con un viaje ya en marcha (p. ej. al reabrir la app).
    if (_kShowDemoDrivers && _isSearching(context.read<ClientRideBloc>().state)) {
      _scheduleDemo();
    }
    // El estado pudo cambiar antes de que esta pantalla empezara a escuchar
    // (el pedido falló, o ya hay un conductor asignado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onRideState(context.read<ClientRideBloc>().state);
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _priceControlTimer?.cancel();
    _waitTimer?.cancel();
    _cancelDemoTimers();
    _controller.dispose();
    _tripController.dispose();
    super.dispose();
  }

  /// El mapa se acerca por pasos conforme avanza el conductor; solo se
  /// reconstruye cuando cambia de paso, no en cada frame.
  void _onTripTick() {
    final step = (_tripController.value * _kZoomSteps).floor();
    if (step != _zoomStep && mounted) {
      setState(() => _zoomStep = step);
    }
  }

  /// El conductor llegó: empieza su espera, que baja segundo a segundo.
  void _startWaitCountdown() {
    _waitTimer?.cancel();
    setState(() => _waitRemaining = _kDriverWaitDuration);
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final next = _waitRemaining - const Duration(seconds: 1);
      setState(() {
        _waitRemaining = next.isNegative ? Duration.zero : next;
      });
      if (_waitRemaining == Duration.zero) timer.cancel();
    });
  }

  /// «Ya voy»: el pasajero avisa que está saliendo.
  void _announceComing() {
    setState(() => _comingAnnounced = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Le avisamos a tu conductor que ya sales.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  /// Posición en pantalla del conductor aceptado respecto al origen: parte
  /// de su lugar inicial y se detiene a [_kArrivedDistance] del punto de
  /// recojo, sin taparlo.
  static Offset _tripDriverOffset(_DemoDriver driver, double progress) {
    final start = driver.offset;
    final distance = start.distance;
    final end = distance <= _kArrivedDistance
        ? start
        : start * (_kArrivedDistance / distance);
    return Offset.lerp(start, end, progress)!;
  }

  void _cancelDemoTimers() {
    for (final timer in _demoTimers) {
      timer.cancel();
    }
    _demoTimers.clear();
  }

  static bool _isSearching(ClientRideState state) {
    return state.status == ClientRideStatus.requesting ||
        state.status == ClientRideStatus.searchingDriver;
  }

  /// true con un conductor real ya asignado: va hacia el pasajero, llegó,
  /// el viaje está en curso o acaba de terminar.
  static bool _isRealTrip(ClientRideState state) {
    if (state.activeRide == null) return false;
    return state.status == ClientRideStatus.driverAssigned ||
        state.status == ClientRideStatus.driverArrived ||
        state.status == ClientRideStatus.tripOngoing ||
        state.status == ClientRideStatus.tripFinished;
  }

  /// Sin viaje ni solicitud: se canceló, falló al crearse o se cerró el
  /// resumen final.
  static bool _isIdle(ClientRideState state) {
    return state.activeRide == null &&
        (state.status == ClientRideStatus.initial ||
            state.status == ClientRideStatus.error);
  }

  /// Última posición que reportó el conductor del viaje, si la hay.
  static LatLng? _driverLatLng(RideEntity? ride) {
    final lat = ride?.driverLat;
    final lng = ride?.driverLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  /// Distancia en línea recta, en metros; `null` si falta algún punto.
  static double? _metersBetween(LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  /// Tiempo estimado para recorrer [meters] (línea recta) en ciudad. Es una
  /// aproximación: [_kRoadFactor] compensa el rodeo por calles y se asume
  /// [_kCitySpeedKmh] de promedio.
  static String? _etaLabel(double? meters) {
    if (meters == null) return null;
    final km = meters / 1000 * _kRoadFactor;
    final minutes = (km / _kCitySpeedKmh * 60).ceil();
    return '${minutes.clamp(1, 99)} min';
  }

  /// Reacciona al estado del viaje: cierra la pantalla cuando ya no hay
  /// viaje, avisa de los errores y, con un conductor real asignado, apaga
  /// la demostración y sigue su avance.
  void _onRideState(ClientRideState state) {
    final error = state.errorMessage;
    if (_isIdle(state)) {
      // El viaje de muestra no depende del estado del bloc: su solicitud
      // real se canceló al aceptarlo.
      if (_demoTrip != null) return;
      if (state.status == ClientRideStatus.error && error != null) {
        _showSnack(error);
      }
      closeRideFlow(context);
      return;
    }
    if (error != null && error != _lastShownError) _showSnack(error);
    _lastShownError = error;

    if (!_isRealTrip(state)) return;
    if (_demoTimers.isNotEmpty || _demoOffer != null) {
      _cancelDemoTimers();
      setState(() {
        _demoOffer = null;
        _demoOfferDriver = null;
      });
    }
    // Ya no se busca conductor: se detiene el latido del punto de origen.
    _controller.stop();

    // Punto de partida de la barra de avance: la mayor distancia vista
    // entre el conductor y su meta en cada etapa.
    final driver = _driverLatLng(state.activeRide);
    if (state.status == ClientRideStatus.driverAssigned) {
      final meters = _metersBetween(driver, state.originLatLng);
      if (meters != null && meters > (_pickupStartMeters ?? 0)) {
        _pickupStartMeters = meters;
      }
    } else if (state.status == ClientRideStatus.tripOngoing) {
      final meters = _metersBetween(driver, state.destLatLng);
      if (meters != null && meters > (_tripStartMeters ?? 0)) {
        _tripStartMeters = meters;
      }
    }

    if (state.status == ClientRideStatus.driverArrived && _waitTimer == null) {
      _startWaitCountdown();
    }
  }

  /// Avance (0–1) hacia la meta dado lo que falta y la distancia inicial.
  static double _progressToward(double? remaining, double? start) {
    if (remaining == null || start == null || start <= 0) return 0;
    return (1 - remaining / start).clamp(0.0, 1.0);
  }

  /// Una solicitud sin conductor tras [_kSearchTimeout] se cancela sola.
  void _checkSearchTimeout() {
    if (_searchTimedOut) return;
    final rideBloc = context.read<ClientRideBloc>();
    final state = rideBloc.state;
    if (state.status != ClientRideStatus.searchingDriver) return;
    final createdAt = state.activeRide?.createdAt;
    if (createdAt == null) return;
    final elapsed = DateTime.now().toUtc().difference(createdAt.toUtc());
    if (elapsed < _kSearchTimeout) return;
    _searchTimedOut = true;
    rideBloc.add(const CancelRide());
    _showSnack('No encontramos un conductor a tiempo. Tu solicitud se canceló.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Cierra el resumen del viaje terminado; el estado vuelve al inicio y
  /// con eso se cierra la pantalla.
  void _dismissFinishedTrip() {
    context.read<ClientRideBloc>().add(const DismissTripCompleted());
  }

  /// «Atrás» del sistema: en pleno trayecto no hace nada; con el viaje
  /// terminado cierra el resumen; en el resto pregunta si se cancela.
  void _onBackPressed() {
    final state = context.read<ClientRideBloc>().state;
    if (_demoTrip == null && _isRealTrip(state)) {
      if (state.status == ClientRideStatus.tripOngoing) return;
      if (state.status == ClientRideStatus.tripFinished) {
        _dismissFinishedTrip();
        return;
      }
    }
    _showCancelDialog();
  }

  /// Programa la demostración: los conductores de muestra aparecen de uno
  /// en uno y, a los 30 s, el primero «envía» una oferta.
  void _scheduleDemo() {
    for (var i = 0; i < _kDemoDrivers.length; i++) {
      _demoTimers.add(
        Timer(_kDemoDrivers[i].appearsAfter, () {
          if (!mounted) return;
          setState(() => _visibleDemoDrivers = i + 1);
        }),
      );
    }
    _demoTimers.add(Timer(_kDemoOfferDelay, () => _showDemoOffer(0)));
  }

  /// El conductor de muestra [driverIndex] «envía» su contraoferta.
  void _showDemoOffer(int driverIndex) {
    if (!mounted || _demoTrip != null) return;
    if (driverIndex >= _kDemoDrivers.length) return;
    final state = context.read<ClientRideBloc>().state;
    // Una oferta real tiene prioridad: no se mezcla con la de muestra.
    if (!_isSearching(state) || state.pendingRideOffers.isNotEmpty) return;
    final driver = _kDemoDrivers[driverIndex];
    setState(() {
      // Quien oferta ya tiene que verse en el mapa.
      if (_visibleDemoDrivers <= driverIndex) {
        _visibleDemoDrivers = driverIndex + 1;
      }
      _demoOfferDriver = driverIndex;
      _demoOffer = DriverOfferView(
        offerId: 'demo-$driverIndex',
        driverId: 'demo-$driverIndex',
        driverName: driver.name,
        rating: driver.rating,
        completedTrips: driver.completedTrips,
        carDescription:
            '${_demoCarFor(state.vehicleCategory)} · ${driver.plate}',
        price: state.offeredPrice + driver.counterOfferDelta,
        isDemo: true,
      );
    });
  }

  /// Modelo de muestra acorde a la categoría elegida.
  static String _demoCarFor(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.standard:
        return 'Toyota Corolla';
      case ClientVehicleCategory.comfort:
        return 'Kia Cerato';
      case ClientVehicleCategory.xl:
        return 'Toyota Fortuner';
      case ClientVehicleCategory.moto:
        return 'Honda CB190';
    }
  }

  static VehicleCategoryOption _vehicleFor(ClientVehicleCategory category) {
    return kVehicleCategoryOptions.firstWhere(
      (o) => o.category == category,
      orElse: () => kVehicleCategoryOptions.first,
    );
  }

  /// Oferta que muestra el panel: la primera real pendiente o, si no hay,
  /// la de muestra.
  DriverOfferView? _currentOffer(ClientRideState state) {
    if (state.pendingRideOffers.isNotEmpty) {
      return DriverOfferView.fromEntity(state.pendingRideOffers.first);
    }
    return _demoOffer;
  }

  void _acceptOffer(DriverOfferView offer) {
    final rideBloc = context.read<ClientRideBloc>();
    if (!offer.isDemo) {
      setState(() => _acceptingOffer = true);
      rideBloc.add(
        AcceptDriverOffer(
          offerId: offer.offerId,
          driverId: offer.driverId,
          finalPrice: offer.price,
        ),
      );
      return;
    }

    // Oferta de muestra aceptada: empieza el viaje simulado. No hay
    // conductor real, así que la solicitud real se cancela para que no
    // quede abierta ante los conductores de verdad.
    final driverIndex = _demoOfferDriver ?? 0;
    final category = rideBloc.state.vehicleCategory;
    _cancelDemoTimers();
    setState(() {
      _demoTrip = _DemoTrip(
        driverIndex: driverIndex,
        carModel: _demoCarFor(category),
        amount: offer.price,
        vehicle: _vehicleFor(category),
      );
      _demoOffer = null;
      _demoOfferDriver = null;
    });
    rideBloc.add(const CancelRide());
    // Ya no se busca conductor: se detiene el latido del punto de origen.
    _controller.stop();
    _tripController.forward(from: 0);
  }

  void _rejectOffer(DriverOfferView offer) {
    if (!offer.isDemo) {
      context.read<ClientRideBloc>().add(RejectRideOffer(offer.offerId));
      return;
    }
    // Rechazada: al rato oferta el siguiente conductor de muestra.
    final next = (_demoOfferDriver ?? 0) + 1;
    setState(() {
      _demoOffer = null;
      _demoOfferDriver = null;
    });
    if (next < _kDemoDrivers.length) {
      _demoTimers.add(
        Timer(_kDemoNextOfferDelay, () => _showDemoOffer(next)),
      );
    }
  }

  void _showDemoUnavailable(String action) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$action estará disponible con un conductor real.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Cancelar: cancela la solicitud o el viaje real (la pantalla se cierra
  /// cuando el estado lo confirma); con el viaje de muestra en curso (ya
  /// sin solicitud real) solo cierra el flujo.
  void _showCancelDialog() {
    final rideBloc = context.read<ClientRideBloc>();
    final onDemoTrip = _demoTrip != null;
    final onTrip = onDemoTrip || _isRealTrip(rideBloc.state);
    showDialog<void>(
      context: context,
      // Con el nombre del flujo, closeRideFlow también cierra este diálogo
      // si la búsqueda termina mientras está abierto.
      routeSettings: const RouteSettings(name: kRideFlowRouteName),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          onTrip ? '¿Cancelar viaje?' : '¿Cancelar búsqueda?',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _kTextDark,
          ),
        ),
        content: Text(
          onTrip
              ? (rideBloc.state.status == ClientRideStatus.driverArrived
                  ? 'Tu conductor ya te está esperando.'
                  : 'Tu conductor ya va en camino hacia ti.')
              : 'Si cancelas, los conductores dejarán de ver tu solicitud.',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              onTrip ? 'Seguir esperando' : 'Continuar buscando',
              style: const TextStyle(color: _kBlue),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              if (!onDemoTrip) {
                rideBloc.add(const CancelRide());
              } else if (mounted) {
                closeRideFlow(context);
              }
            },
            child: const Text(
              'Cancelar',
              style: TextStyle(
                color: _kCancelRed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Mide el panel inferior tras cada frame: su alto real es el que decide
  /// dónde queda el centro de la franja libre del mapa.
  void _measureBottomPanel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _bottomPanelKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final height = box.size.height;
      if ((height - _bottomPanelHeight).abs() > 1) {
        setState(() => _bottomPanelHeight = height);
      }
    });
  }

  /// Cuenta regresiva como «m:ss».
  static String _formatCountdown(Duration remaining) {
    final seconds = remaining.inSeconds.clamp(0, 5999);
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '${seconds ~/ 60}:$rest';
  }

  /// Tiempo de llegada restante del viaje de muestra según su avance.
  static String _tripEtaLabel(_DemoTrip trip, double progress) {
    final minutes = (trip.driver.etaMinutes * (1 - progress)).ceil();
    return '${minutes.clamp(1, 99)} min';
  }

  @override
  Widget build(BuildContext context) {
    _measureBottomPanel();
    final topInset = MediaQuery.paddingOf(context).top;
    // Zona tapada arriba (cabecera) y abajo (panel): el mapa centra el
    // origen en la franja que queda entre ambas, y las olas se dibujan en
    // ese mismo centro.
    final coveredTop = topInset + _headerTopMargin + _headerHeight;
    final coveredBottom = _bottomPanelHeight;
    final state = context.watch<ClientRideBloc>().state;
    final realTrip = _isRealTrip(state);
    final hasRealOffer = state.pendingRideOffers.isNotEmpty;
    final trip = _demoTrip;
    final hasOffer =
        !realTrip && trip == null && (hasRealOffer || _demoOffer != null);
    // Con una oferta real en pantalla no se resalta a nadie de muestra.
    final offeringDriver = hasRealOffer ? null : _demoOfferDriver;

    return BlocListener<ClientRideBloc, ClientRideState>(
      listenWhen: (p, c) =>
          p.status != c.status ||
          p.activeRide != c.activeRide ||
          p.errorMessage != c.errorMessage ||
          p.pendingRideOffers != c.pendingRideOffers,
      listener: (context, state) {
        _onRideState(state);
        // La lista de ofertas cambió (p. ej. la aceptada dejó de estar
        // pendiente) o la aceptación falló: los botones vuelven a responder.
        if (_acceptingOffer && mounted) {
          setState(() => _acceptingOffer = false);
        }
      },
      // «Atrás» no vuelve al paso de vehículo con la búsqueda o el viaje en
      // marcha: pregunta si se cancela.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _onBackPressed();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Positioned.fill(
                child: RoutePreviewMap(
                  // Buscando (o en el viaje de muestra) el mapa se centra en
                  // el origen; con un conductor real muestra dónde va.
                  focusOrigin: !realTrip,
                  driverLatLng:
                      realTrip ? _driverLatLng(state.activeRide) : null,
                  fitToDriver:
                      state.status == ClientRideStatus.driverAssigned ||
                          state.status == ClientRideStatus.driverArrived,
                  // Buscando conductor (y mientras viene) solo se ve el
                  // punto de recojo; el destino y la ruta vuelven al
                  // empezar el trayecto.
                  showDestination:
                      state.status == ClientRideStatus.tripOngoing ||
                          state.status == ClientRideStatus.tripFinished,
                  recenterToken: _recenterToken,
                  // Con el conductor de muestra en camino, el mapa se va
                  // acercando.
                  originZoom: RoutePreviewMap.defaultOriginZoom +
                      (_kArrivedZoom - RoutePreviewMap.defaultOriginZoom) *
                          (_zoomStep / _kZoomSteps),
                  mapPadding: EdgeInsets.only(
                    top: coveredTop,
                    bottom: coveredBottom,
                  ),
                ),
              ),
              // Olas del punto de origen y conductores cercanos. Con un
              // conductor real asignado, el origen y él van en el mapa.
              if (!realTrip)
                Positioned(
                  left: 0,
                  right: 0,
                  top: coveredTop,
                  bottom: coveredBottom,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _tripController,
                      builder: (context, waves) {
                        final progress = _tripController.value;
                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            waves!,
                            if (_kShowDemoDrivers)
                              for (var i = 0; i < _kDemoDrivers.length; i++)
                                Transform.translate(
                                  // El conductor aceptado se acerca al
                                  // origen conforme avanza el viaje.
                                  offset: trip != null && trip.driverIndex == i
                                      ? _tripDriverOffset(
                                          _kDemoDrivers[i],
                                          progress,
                                        )
                                      : _kDemoDrivers[i].offset,
                                  child: _NearbyDriverMarker(
                                    etaLabel: trip != null &&
                                            trip.driverIndex == i
                                        ? (progress >= 1
                                            ? 'Llegó'
                                            : _tripEtaLabel(trip, progress))
                                        : '${_kDemoDrivers[i].etaMinutes} min',
                                    // Aceptado un conductor, los demás
                                    // desaparecen.
                                    visible: trip != null
                                        ? trip.driverIndex == i
                                        : i < _visibleDemoDrivers,
                                    highlighted: trip != null
                                        ? trip.driverIndex == i
                                        : offeringDriver == i,
                                  ),
                                ),
                          ],
                        );
                      },
                      // Las ondas son solo de la búsqueda: con un conductor
                      // aceptado queda el punto de origen, sin latido.
                      child: _OriginWaves(
                        animation: _controller,
                        showWaves: trip == null,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: topInset + _headerTopMargin,
                left: 16,
                right: 16,
                height: _headerHeight,
                child: realTrip
                    ? _buildRealTripHeader(state)
                    : trip != null
                        ? _buildDemoTripHeader(trip)
                        : _buildHeader(hasOffer: hasOffer),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: KeyedSubtree(
                  key: _bottomPanelKey,
                  child: _buildBottomPanel(context, state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de la cabecera con el conductor ya asignado: volver
  /// (izquierda, si [onBack] no es `null`), mensaje y tiempo (centro) y
  /// «centrar mapa» (derecha).
  Widget _tripHeaderCard({
    required VoidCallback? onBack,
    required Widget child,
  }) {
    Widget roundButton(IconData icon, String tooltip, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _kTextDark, size: 20),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          if (onBack != null)
            roundButton(Icons.arrow_back_rounded, 'Volver', onBack)
          else
            const SizedBox(width: 40),
          Expanded(child: child),
          roundButton(
            Icons.my_location_rounded,
            'Centrar mapa',
            () => setState(() => _recenterToken++),
          ),
        ],
      ),
    );
  }

  static Widget _tripHeaderTexts(String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildDemoTripHeader(_DemoTrip trip) {
    return _tripHeaderCard(
      onBack: _showCancelDialog,
      child: AnimatedBuilder(
        animation: _tripController,
        builder: (context, _) {
          final progress = _tripController.value;
          final arrived = progress >= 1;
          return _tripHeaderTexts(
            arrived ? 'Tu conductor llegó' : 'Conductor va hacia ti',
            arrived
                ? 'Te espera ${_formatCountdown(_waitRemaining)}'
                : 'Llega en ${_tripEtaLabel(trip, progress)}',
          );
        },
      ),
    );
  }

  /// Cabecera del viaje real, según su etapa.
  Widget _buildRealTripHeader(ClientRideState state) {
    final driver = _driverLatLng(state.activeRide);
    switch (state.status) {
      case ClientRideStatus.driverArrived:
        return _tripHeaderCard(
          onBack: _showCancelDialog,
          child: _tripHeaderTexts(
            'Tu conductor llegó',
            'Te espera ${_formatCountdown(_waitRemaining)}',
          ),
        );
      case ClientRideStatus.tripOngoing:
        final eta = _etaLabel(_metersBetween(driver, state.destLatLng));
        return _tripHeaderCard(
          // En pleno trayecto ya no hay nada que cancelar desde aquí.
          onBack: null,
          child: _tripHeaderTexts(
            'En camino a tu destino',
            eta == null ? 'Viaje en curso' : 'Llegas en $eta',
          ),
        );
      case ClientRideStatus.tripFinished:
        return _tripHeaderCard(
          onBack: _dismissFinishedTrip,
          child: _tripHeaderTexts(
            'Viaje finalizado',
            '¡Gracias por viajar con Lleva!',
          ),
        );
      default:
        final eta = _etaLabel(_metersBetween(driver, state.originLatLng));
        return _tripHeaderCard(
          onBack: _showCancelDialog,
          child: _tripHeaderTexts(
            'Conductor va hacia ti',
            eta == null ? 'En camino' : 'Llega en $eta',
          ),
        );
    }
  }

  /// Descripción del panel inferior según la categoría elegida.
  static String _selectionMessage(ClientVehicleCategory category) {
    switch (category) {
      case ClientVehicleCategory.standard:
        return 'Has seleccionado un taxi del tipo Estándar.';
      case ClientVehicleCategory.comfort:
        return 'Has seleccionado un taxi del tipo Confort.';
      case ClientVehicleCategory.xl:
        return 'Has seleccionado un taxi del tipo XL.';
      case ClientVehicleCategory.moto:
        return 'Has seleccionado una moto.';
    }
  }

  Widget _buildHeader({required bool hasOffer}) {
    final message = hasOffer
        ? '¡Un conductor te envió una oferta!'
        : _searchMessages[_messageIndex];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Text(
                message,
                key: ValueKey(message),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _kTextDark,
                  height: 1.25,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (hasOffer)
            const Icon(Icons.local_offer_rounded, color: _kBlue, size: 24)
          else
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: _kBlue,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context, ClientRideState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
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
          const SizedBox(height: 18),
          _buildBottomPanelContent(state),
        ],
      ),
    );
  }

  Widget _buildBottomPanelContent(ClientRideState state) {
    // Conductor real asignado: va en camino, llegó, viaje en curso o fin.
    if (_isRealTrip(state)) return _buildRealTripPanel(state);

    // Oferta de muestra aceptada: el conductor simulado va en camino.
    final trip = _demoTrip;
    if (trip != null) {
      return AnimatedBuilder(
        animation: _tripController,
        builder: (context, _) {
          final progress = _tripController.value;
          return DriverOnTheWayPanel(
            driverName: trip.driver.name,
            etaLabel: _tripEtaLabel(trip, progress),
            progress: progress,
            arrived: progress >= 1,
            waitRemaining: _waitRemaining,
            waitTotal: _kDriverWaitDuration,
            comingAnnounced: _comingAnnounced,
            onComing: _announceComing,
            rating: trip.driver.rating,
            carModel: trip.carModel,
            plate: trip.driver.plate,
            vehicle: trip.vehicle,
            approvedAmount: trip.amount,
            onCall: () => _showDemoUnavailable('Llamar'),
            onMessage: () => _showDemoUnavailable('El chat'),
            onCancel: _showCancelDialog,
          );
        },
      );
    }

    // Con una oferta, el panel cambia al diseño del conductor.
    final offer = _currentOffer(state);
    if (offer != null) {
      return DriverOfferPanel(
        offer: offer,
        passengerPrice: state.offeredPrice,
        vehicle: _vehicleFor(state.vehicleCategory),
        isBusy: _acceptingOffer,
        onAccept: () => _acceptOffer(offer),
        onReject: () => _rejectOffer(offer),
      );
    }

    // Pasados [_kPriceControlsDelay] sin conductor, se puede ajustar la
    // oferta (también la ven los conductores: se guarda en el viaje).
    final canAdjustPrice = _showPriceControls &&
        state.status == ClientRideStatus.searchingDriver;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Buscando tu mejor taxi',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectionMessage(state.vehicleCategory),
          style: const TextStyle(
            fontSize: 14,
            color: _kTextMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EEFF)),
          ),
          child: _SelectedVehicleRow(state: state),
        ),
        const SizedBox(height: 12),
        _ViewersRow(viewersCount: state.viewersCount),
        const SizedBox(height: 14),
        if (canAdjustPrice) ...[
          _OfferAdjuster(state: state),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: _showCancelDialog,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _kCancelRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Cancelar búsqueda',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Panel del viaje real según su etapa, con los datos del conductor que
  /// trae el viaje ([ClientRideState.activeRide]).
  Widget _buildRealTripPanel(ClientRideState state) {
    final ride = state.activeRide!;
    final amount = ride.finalPrice ?? ride.offeredPrice;
    if (state.status == ClientRideStatus.tripFinished) {
      return _TripFinishedSummary(
        amount: amount,
        paymentMethod: ride.paymentMethod,
        onClose: _dismissFinishedTrip,
      );
    }

    final ongoing = state.status == ClientRideStatus.tripOngoing;
    // Lo que le falta al conductor: hasta el recojo o, ya con el pasajero,
    // hasta el destino.
    final remaining = _metersBetween(
      _driverLatLng(ride),
      ongoing ? state.destLatLng : state.originLatLng,
    );
    final name = ride.driverFullName?.trim() ?? '';
    final car = [ride.driverCarBrand, ride.driverCarModel]
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join(' ');
    final destination = (state.destName ?? ride.destName).split('\n').first;

    return DriverOnTheWayPanel(
      driverName: name.isEmpty ? 'Conductor' : name,
      title: ongoing ? 'En camino a tu destino' : null,
      subtitle: ongoing ? destination : null,
      etaLabel: _etaLabel(remaining) ?? 'En camino',
      progress: _progressToward(
        remaining,
        ongoing ? _tripStartMeters : _pickupStartMeters,
      ),
      arrived: state.status == ClientRideStatus.driverArrived,
      waitRemaining: _waitRemaining,
      waitTotal: _kDriverWaitDuration,
      photoUrl: ride.driverProfilePicUrl,
      rating: ride.driverRating,
      carModel: car.isEmpty ? null : car,
      plate: ride.driverCarPlate,
      vehicle: _vehicleFor(state.vehicleCategory),
      approvedAmount: amount,
      onCall: () => _showSnack('Llamar al conductor aún no está disponible.'),
      onMessage: () =>
          _showSnack('El chat con el conductor aún no está disponible.'),
      // Con el pasajero ya a bordo no se cancela desde aquí.
      onCancel: ongoing ? null : _showCancelDialog,
      // «Ya voy» todavía no llega a la app del conductor: sin botón, para
      // no decirle al pasajero que se le avisó.
      onComing: null,
    );
  }
}

/// Resumen al terminar el viaje: total, forma de pago y «Cerrar».
class _TripFinishedSummary extends StatelessWidget {
  const _TripFinishedSummary({
    required this.amount,
    required this.paymentMethod,
    required this.onClose,
  });

  final double amount;
  final String paymentMethod;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_rounded, color: _kLiveGreen, size: 52),
        const SizedBox(height: 10),
        const Text(
          '¡Llegaste a tu destino!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EEFF)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total del viaje',
                      style: TextStyle(fontSize: 12, color: _kTextMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _SelectedVehicleRow._paymentIcon(paymentMethod),
                        const SizedBox(width: 5),
                        Text(
                          _SelectedVehicleRow._paymentLabel(paymentMethod),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                'S/ ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _kBlue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Cerrar',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Punto de origen. Mientras se busca conductor lo rodean ondas que se
/// expanden y se desvanecen, como un latido ([animation] recorre 0→1 en
/// bucle; cada onda va desfasada).
class _OriginWaves extends StatelessWidget {
  const _OriginWaves({required this.animation, this.showWaves = true});

  final Animation<double> animation;

  /// false = solo el punto, sin ondas (ya no se está buscando conductor).
  final bool showWaves;

  static const double _size = 220;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        painter: _OriginWavesPainter(animation, showWaves: showWaves),
      ),
    );
  }
}

class _OriginWavesPainter extends CustomPainter {
  _OriginWavesPainter(this.animation, {required this.showWaves})
      : super(repaint: animation);

  final Animation<double> animation;
  final bool showWaves;

  static const int _waveCount = 3;
  static const double _dotRadius = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    for (var i = 0; showWaves && i < _waveCount; i++) {
      // Cada onda nace en el punto, crece hasta el borde y se apaga.
      final t = (animation.value + i / _waveCount) % 1.0;
      final radius = _dotRadius + (maxRadius - _dotRadius) * t;
      final fade = 1.0 - t;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = _kBlue.withValues(alpha: 0.22 * fade),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _kBlue.withValues(alpha: 0.45 * fade),
      );
    }

    // Punto de origen: azul con borde blanco y sombra suave.
    canvas.drawCircle(
      center.translate(0, 1.5),
      _dotRadius + 3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, _dotRadius + 3, Paint()..color = Colors.white);
    canvas.drawCircle(center, _dotRadius, Paint()..color = _kBlue);
  }

  @override
  bool shouldRepaint(covariant _OriginWavesPainter oldDelegate) =>
      oldDelegate.animation != animation ||
      oldDelegate.showWaves != showWaves;
}

/// Conductor cercano en el mapa: un círculo (donde luego irá su foto) y su
/// tiempo de llegada. Aparece con un pequeño salto cuando [visible] pasa a
/// true. Con [highlighted] (envió una oferta o fue el elegido) se agranda
/// un poco y su contorno pasa a amarillo.
class _NearbyDriverMarker extends StatelessWidget {
  const _NearbyDriverMarker({
    required this.etaLabel,
    required this.visible,
    this.highlighted = false,
  });

  final String etaLabel;
  final bool visible;
  final bool highlighted;

  static const Color _highlightYellow = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final double scale;
    if (!visible) {
      scale = 0.3;
    } else {
      scale = highlighted ? 1.25 : 1.0;
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: visible ? 1 : 0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEEF5FF),
                border: Border.all(
                  color: highlighted ? _highlightYellow : Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded, color: _kBlue, size: 24),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kTextDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                etaLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vehículo elegido, método de pago y oferta enviada.
class _SelectedVehicleRow extends StatelessWidget {
  const _SelectedVehicleRow({required this.state});

  final ClientRideState state;

  static String _paymentLabel(String method) {
    switch (method) {
      case 'yape':
        return 'Yape';
      case 'plin':
        return 'Plin';
      default:
        return 'Efectivo';
    }
  }

  static Widget _paymentIcon(String method) {
    switch (method) {
      case 'yape':
        return Image.asset('assets/icons/IconoYape.png', width: 18, height: 18);
      case 'plin':
        return Image.asset('assets/icons/IconoPlin.png', width: 18, height: 18);
      default:
        return const Icon(
          Icons.payments_rounded,
          color: Color(0xFF2E7D32),
          size: 16,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final option = kVehicleCategoryOptions.firstWhere(
      (o) => o.category == state.vehicleCategory,
      orElse: () => kVehicleCategoryOptions.first,
    );
    return Row(
      children: [
        // Misma foto del vehículo que en el paso 3.
        SizedBox(
          width: 76,
          height: 48,
          child: Image.asset(
            option.image,
            fit: BoxFit.contain,
            cacheWidth: 300,
            errorBuilder: (_, __, ___) =>
                Icon(option.icon, size: 30, color: option.accent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                option.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  _paymentIcon(state.paymentMethod),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _paymentLabel(state.paymentMethod),
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
        Text(
          'S/ ${state.offeredPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _kBlue,
          ),
        ),
      ],
    );
  }
}

/// Ajuste de la oferta durante la búsqueda: precio actual y botones − / +.
/// Cada cambio se guarda en el viaje ([BoostOfferedPrice]) para que los
/// conductores vean el precio nuevo. No baja de la tarifa sugerida − S/ 2.
class _OfferAdjuster extends StatelessWidget {
  const _OfferAdjuster({required this.state});

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    final current = state.offeredPrice;
    final lower = ClientRidePricing.decreaseOffered(
      current: current,
      suggestedPrice: state.suggestedPrice,
    );
    final higher = ClientRidePricing.increaseOffered(current);
    final canLower = lower < current;

    Widget stepButton({
      required IconData icon,
      required Color background,
      required Color foreground,
      required VoidCallback? onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: foreground, size: 18),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EEFF)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ajusta tu oferta',
                style: TextStyle(fontSize: 11, color: _kTextMuted),
              ),
              Text(
                'S/ ${current.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kBlue,
                ),
              ),
            ],
          ),
          Row(
            children: [
              stepButton(
                icon: Icons.remove_rounded,
                background: const Color(0xFFFFEEEE),
                foreground: const Color(0xFFCC2200),
                onTap: canLower
                    ? () => rideBloc.add(BoostOfferedPrice(lower))
                    : null,
              ),
              const SizedBox(width: 8),
              stepButton(
                icon: Icons.add_rounded,
                background: const Color(0xFFEEF5FF),
                foreground: _kBlue,
                onTap: () => rideBloc.add(BoostOfferedPrice(higher)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Conductores que han visto la solicitud, según el dato real del bloc
/// ([ClientRideState.viewersCount]): avatares superpuestos (hasta 4, con
/// «+N» si hay más) y el texto. Con cero, un texto neutro sin avatares.
class _ViewersRow extends StatelessWidget {
  const _ViewersRow({required this.viewersCount});

  final int viewersCount;

  static const List<Color> _avatarColors = [
    Color(0xFF0066CC),
    Color(0xFF00AA44),
    Color(0xFF9C27B0),
    Color(0xFFFF6B35),
  ];

  @override
  Widget build(BuildContext context) {
    final count = viewersCount < 0 ? 0 : viewersCount;
    final shown = count.clamp(0, 4);
    final String message;
    if (count == 0) {
      message = 'Oferta visible para conductores cercanos';
    } else if (count == 1) {
      message = '1 conductor viendo tu oferta';
    } else {
      message = '$count conductores viendo tu oferta';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shown > 0) ...[
          Row(
            children: [
              SizedBox(
                width: 32 + (shown - 1) * 20.0,
                height: 32,
                child: Stack(
                  children: [
                    for (var i = 0; i < shown; i++)
                      Positioned(
                        left: i * 20.0,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Fondo opaco para que los avatares no se
                            // transparenten al superponerse.
                            color: Color.alphaBlend(
                              _avatarColors[i % 4].withValues(alpha: 0.15),
                              Colors.white,
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: _avatarColors[i % 4],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (count > 4) ...[
                const SizedBox(width: 6),
                Text(
                  '+${count - 4}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kLiveGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Text(
                    message,
                    key: ValueKey(message),
                    style: const TextStyle(
                      fontSize: 13,
                      color: _kTextDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
