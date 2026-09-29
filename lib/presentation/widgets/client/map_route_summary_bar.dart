import 'dart:developer' show log;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/enums/client_ride_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/client_ride/client_ride_bloc.dart';

/// True cuando debe mostrarse el resumen origen/destino sobre el mapa.
bool clientDashboardShouldShowRouteSummary(ClientRideState state) {
  if (state.activeRide != null) return true;
  return state.status == ClientRideStatus.readyToRequest;
}

String _firstAddressLine(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  return raw.split('\n').first.trim();
}

String _summaryOriginLabel(ClientRideState state) {
  if (state.originName != null && state.originName!.isNotEmpty) {
    return _firstAddressLine(state.originName);
  }
  final r = state.activeRide;
  if (r != null) return _firstAddressLine(r.originName);
  return '—';
}

String _summaryDestLabel(ClientRideState state) {
  if (state.destName != null && state.destName!.isNotEmpty) {
    return _firstAddressLine(state.destName);
  }
  final r = state.activeRide;
  if (r != null) return _firstAddressLine(r.destName);
  return '—';
}

int _routeMinutesForSummary(ClientRideState state) {
  final seconds = state.routeDurationSeconds;
  if (seconds != null && seconds > 0) {
    return (seconds / 60.0).ceil().clamp(1, 999);
  }
  final km = state.routeDistanceKm;
  if (km != null && km > 0) {
    return (km / 30.0 * 60.0).ceil().clamp(1, 999);
  }
  return 0;
}

String? _routeStatsLineForSummary(ClientRideState state) {
  if (state.status != ClientRideStatus.readyToRequest) return null;
  final km = state.routeDistanceKm;
  if (km == null || km <= 0) return null;
  final minutes = _routeMinutesForSummary(state);
  if (minutes <= 0) return '${km.toStringAsFixed(1)} km';
  return '$minutes min · ${km.toStringAsFixed(1)} km';
}

/// Columna visual: origen (círculo cyan) — línea — destino (cuadrado cyan).
class _RouteConnectorColumn extends StatelessWidget {
  const _RouteConnectorColumn();

  static const Color _cyan = Color(0xFF00D4FF);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: _cyan,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 2,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _cyan,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

/// Barra superior con resumen de ruta (cristal + conectores + edición unificada).
class MapRouteSummaryBar extends StatefulWidget {
  const MapRouteSummaryBar({
    super.key,
    required this.onScrollPanelToTop,
  });

  final VoidCallback onScrollPanelToTop;

  @override
  State<MapRouteSummaryBar> createState() => _MapRouteSummaryBarState();
}

class _MapRouteSummaryBarState extends State<MapRouteSummaryBar> {
  String? _debugRouteSummaryLayoutSig;

  void _debugLog(String message, {int level = 800}) {
    if (!kDebugMode) return;
    log(message, name: 'LlevaClientDashboard', level: level);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientRideBloc, ClientRideState>(
      builder: (context, state) {
        final topPad = MediaQuery.paddingOf(context).top + 10;
        return Positioned(
          top: topPad,
          left: 12,
          right: 12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final mqSize = MediaQuery.sizeOf(context);
              final badW = !w.isFinite || w <= 0;
              final lbStr =
                  w.isFinite ? w.toStringAsFixed(1) : w.toString();
              final mqWStr = mqSize.width.isFinite
                  ? mqSize.width.toStringAsFixed(1)
                  : mqSize.width.toString();
              if (kDebugMode) {
                final sig = '${state.status}|lb:$lbStr|mq:$mqWStr';
                if (badW || sig != _debugRouteSummaryLayoutSig) {
                  _debugRouteSummaryLayoutSig = badW ? null : sig;
                  _debugLog(
                    'routeSummaryBar layout: '
                    'LayoutBuilder maxW=$w minW=${constraints.minWidth} '
                    'maxH=${constraints.maxHeight} '
                    'MediaQuery.size=${mqSize.width}x${mqSize.height} '
                    'status=${state.status} '
                    'originNameLen=${state.originName?.length ?? 0} '
                    'destNameLen=${state.destName?.length ?? 0}',
                    level: badW ? 1000 : 800,
                  );
                }
              }
              if (badW) {
                return const SizedBox.shrink();
              }
              return _MapRouteSummaryBarContent(
                state: state,
                onScrollPanelToTop: widget.onScrollPanelToTop,
              );
            },
          ),
        );
      },
    );
  }
}

class _MapRouteSummaryBarContent extends StatelessWidget {
  const _MapRouteSummaryBarContent({
    required this.state,
    required this.onScrollPanelToTop,
  });

  final ClientRideState state;
  final VoidCallback onScrollPanelToTop;

  void _onEditRoute(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    rideBloc.add(const StartEditingDest());
    onScrollPanelToTop();
  }

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    final canEdit = state.status == ClientRideStatus.readyToRequest;
    final originText = _summaryOriginLabel(state);
    final destText = _summaryDestLabel(state);
    final destRouteStats = _routeStatsLineForSummary(state);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (state.status == ClientRideStatus.readyToRequest)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 22,
                    ),
                    tooltip: 'Volver',
                    onPressed: () {
                      rideBloc.add(const BackToSearchPanel());
                    },
                  )
                else
                  const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: canEdit
                          ? () => _onEditRoute(context)
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      splashColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      highlightColor: Colors.white.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const _RouteConnectorColumn(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    originText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    destText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                  if (destRouteStats != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      destRouteStats,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF00D4FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
