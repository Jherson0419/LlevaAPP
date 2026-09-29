import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/client_ride_status.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';
import 'client_menu_fab.dart';
import 'map/client_map_layer.dart';
import 'map_route_summary_bar.dart';
import 'panels/driver_arrived_panel.dart';
import 'panels/driver_assigned_panel.dart';
import 'panels/negotiating_panel.dart';
import 'panels/ready_to_request_panel.dart';
import 'panels/search_location_panel.dart';
import 'panels/searching_driver_panel.dart';
import 'panels/trip_finished_panel.dart';
import 'panels/trip_ongoing_panel.dart';

/// Stack principal del dashboard cliente: mapa, paneles inferiores, FAB y resumen de ruta.
class ClientDashboardMainStack extends StatelessWidget {
  const ClientDashboardMainStack({
    super.key,
    required this.scaffoldKey,
    required this.bodyStackKey,
    required this.mapLayerKey,
    required this.pulseController,
    required this.panelScrollController,
    required this.originController,
    required this.destController,
    required this.priceController,
    required this.originFocusNode,
    required this.destFocusNode,
    required this.onScrollPanelToTop,
    required this.mapGestureActiveListenable,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final GlobalKey bodyStackKey;
  final GlobalKey mapLayerKey;
  final AnimationController pulseController;
  final ScrollController panelScrollController;
  final TextEditingController originController;
  final TextEditingController destController;
  final TextEditingController priceController;
  final FocusNode originFocusNode;
  final FocusNode destFocusNode;
  final VoidCallback onScrollPanelToTop;
  final ValueNotifier<bool> mapGestureActiveListenable;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: bodyStackKey,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          key: mapLayerKey,
          child: ClientMapLayer(
            mapGestureActiveNotifier: mapGestureActiveListenable,
            searchPulseController: pulseController,
            originFocusNode: originFocusNode,
            destFocusNode: destFocusNode,
          ),
        ),
        BlocBuilder<ClientRideBloc, ClientRideState>(
          builder: (context, state) {
            if (clientDashboardShouldShowRouteSummary(state)) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: MediaQuery.of(context).padding.left + 16,
              child: ClientMenuFAB(
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: mapGestureActiveListenable,
          builder: (context, shouldHideByGesture, _) {
            return BlocBuilder<ClientRideBloc, ClientRideState>(
              builder: (context, state) {
            Widget content;
            if (state.status == ClientRideStatus.searchingDriver &&
                state.activeRide != null &&
                state.pendingRideOffers.isNotEmpty) {
              content = Positioned.fill(
                child: NegotiatingPanel(state: state),
              );
            } else if (state.status == ClientRideStatus.requesting ||
                state.status == ClientRideStatus.searchingDriver) {
              content = Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Material(
                    color: const Color(0xFF1A1A1A),
                    elevation: 12,
                    shadowColor: Colors.black54,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: SearchingDriverPanel(state: state),
                      ),
                    ),
                  ),
                ),
              );
            } else if (state.status == ClientRideStatus.readyToRequest) {
              content = ReadyToRequestLayer(
                priceController: priceController,
              );
            } else {
              content = Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: Material(
                    color: const Color(0xFF1A1A1A),
                    elevation: 12,
                    shadowColor: Colors.black54,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.55,
                      ),
                      child: SingleChildScrollView(
                        controller: panelScrollController,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: BlocBuilder<ClientRideBloc, ClientRideState>(
                          builder: (context, state) {
                            if (state.status == ClientRideStatus.tripFinished &&
                                state.activeRide != null) {
                              return TripFinishedPanel(state: state);
                            }

                            if (state.status == ClientRideStatus.driverArrived &&
                                state.activeRide != null) {
                              return DriverArrivedPanel(state: state);
                            }

                            if (state.status == ClientRideStatus.tripOngoing &&
                                state.activeRide != null) {
                              return TripOngoingPanel(state: state);
                            }

                            if (state.status ==
                                    ClientRideStatus.driverAssigned &&
                                state.activeRide != null) {
                              return DriverAssignedPanel(state: state);
                            }

                            return SearchLocationPanel(
                              originController: originController,
                              destController: destController,
                              originFocusNode: originFocusNode,
                              destFocusNode: destFocusNode,
                              state: state,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              opacity: shouldHideByGesture ? 0 : 1,
              child: IgnorePointer(
                ignoring: shouldHideByGesture,
                child: content,
              ),
            );
          },
            );
          },
        ),
        BlocBuilder<ClientRideBloc, ClientRideState>(
          builder: (context, state) {
            if (!clientDashboardShouldShowRouteSummary(state)) {
              return const SizedBox.shrink();
            }
            return MapRouteSummaryBar(
              onScrollPanelToTop: onScrollPanelToTop,
            );
          },
        ),
      ],
    );
  }
}
