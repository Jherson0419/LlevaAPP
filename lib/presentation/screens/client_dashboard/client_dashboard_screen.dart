import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/enums/client_ride_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import '../../widgets/client/client_dashboard_main_stack.dart';
import '../../widgets/client/client_drawer.dart';

class ClientDashboardScreen extends StatefulWidget {
  const ClientDashboardScreen({super.key});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final FocusNode _originFocusNode = FocusNode();
  final FocusNode _destFocusNode = FocusNode();
  late final AnimationController _pulseController;

  /// Evita pisar la tarifa al escribir; se actualiza al cambiar categoría o extras.
  String? _lastTariffSyncKey;
  final ScrollController _panelScrollController = ScrollController();
  final GlobalKey _bodyStackKey = GlobalKey();
  final GlobalKey _mapLayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const RefreshProfileEvent());
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    _priceController.dispose();
    _originFocusNode.dispose();
    _destFocusNode.dispose();
    _pulseController.dispose();
    _panelScrollController.dispose();
    super.dispose();
  }

  void _scrollPanelToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_panelScrollController.hasClients) {
        _panelScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<ClientRideBloc>(),
      child: Builder(
        builder: (context) {
          final drawerWidth = MediaQuery.sizeOf(context).width * 0.78;

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: AppTheme.darkBackground,
            drawer: Drawer(
              width: drawerWidth,
              backgroundColor: const Color(0xFF0A0A0A),
              child: ClientDrawer(
                hostContext: context,
                onCityTap: () {},
              ),
            ),
            body: BlocListener<ClientRideBloc, ClientRideState>(
              listener: (context, state) {
                if (state.status == ClientRideStatus.initial &&
                    state.originLatLng == null &&
                    state.destLatLng == null &&
                    state.activeRide == null &&
                    state.originName == null &&
                    state.destName == null) {
                  if (_priceController.text.isNotEmpty) {
                    _priceController.clear();
                  }
                  if (_originController.text.isNotEmpty) {
                    _originController.clear();
                  }
                  if (_destController.text.isNotEmpty) {
                    _destController.clear();
                  }
                  _lastTariffSyncKey = null;
                }
                if (state.status == ClientRideStatus.readyToRequest &&
                    state.offeredPrice > 0) {
                  final key =
                      '${state.routeBaseSuggested}_${state.vehicleCategory.name}_${state.moreThanFourPassengers}_${state.babySeat}_${state.pet}_${state.suggestedPrice?.toStringAsFixed(2)}';
                  if (key != _lastTariffSyncKey) {
                    _lastTariffSyncKey = key;
                    _priceController.text =
                        state.offeredPrice.toStringAsFixed(2);
                  }
                } else if (state.status != ClientRideStatus.readyToRequest) {
                  _lastTariffSyncKey = null;
                }
              },
              child: ClientDashboardMainStack(
                scaffoldKey: _scaffoldKey,
                bodyStackKey: _bodyStackKey,
                mapLayerKey: _mapLayerKey,
                pulseController: _pulseController,
                panelScrollController: _panelScrollController,
                originController: _originController,
                destController: _destController,
                priceController: _priceController,
                originFocusNode: _originFocusNode,
                destFocusNode: _destFocusNode,
                onScrollPanelToTop: _scrollPanelToTop,
              ),
            ),
          );
        },
      ),
    );
  }
}
