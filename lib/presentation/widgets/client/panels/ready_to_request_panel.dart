import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/enums/client_ride_status.dart';
import '../../../../core/enums/client_vehicle_category.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/client_ride_pricing.dart';
import '../../../bloc/auth/auth_bloc.dart';
import '../../../bloc/auth/auth_state.dart';
import '../../../bloc/client_ride/client_ride_bloc.dart';
import '../client_payment_method_ui.dart';
import '../client_ride_preferences_sheet.dart';

const Color _kRidePriceCyan = Color(0xFF00D4FF);

/// Campo central de tarifa con [prefixText] S/, estilo cyan y feedback al toque.
class _RidePriceCenterField extends StatefulWidget {
  const _RidePriceCenterField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_RidePriceCenterField> createState() => _RidePriceCenterFieldState();
}

class _RidePriceCenterFieldState extends State<_RidePriceCenterField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const priceStyle = TextStyle(
      color: _kRidePriceCyan,
      fontSize: 30,
      fontWeight: FontWeight.w800,
    );

    return Material(
      color: AppTheme.darkSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => FocusScope.of(context).requestFocus(_focusNode),
        borderRadius: BorderRadius.circular(16),
        splashColor: _kRidePriceCyan.withValues(alpha: 0.18),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: priceStyle,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            filled: false,
            prefixText: 'S/ ',
            prefixStyle: priceStyle,
            hintText: '0.00',
            hintStyle: TextStyle(
              color: AppTheme.darkTextSecondary.withValues(alpha: 0.85),
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 14,
            ),
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

/// Tarifa editable en el panel deslizable de [ready_to_request].
class RidePriceSection extends StatelessWidget {
  const RidePriceSection({
    super.key,
    required this.priceController,
    required this.state,
  });

  final TextEditingController priceController;
  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    final suggested = state.suggestedPrice;

    void applyPriceFromField(String value) {
      final normalized = value.replaceAll(',', '.');
      final price = double.tryParse(normalized) ?? 0;
      rideBloc.add(PriceChanged(price));
    }

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
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Material(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(14),
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final cur = state.offeredPrice > 0
                            ? state.offeredPrice
                            : (suggested ?? 5);
                        final next = ClientRidePricing.decreaseOffered(
                          current: cur,
                          suggestedPrice: suggested,
                        );
                        priceController.text = next.toStringAsFixed(2);
                        rideBloc.add(PriceChanged(next));
                      },
                      icon: const Icon(
                        Icons.remove,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RidePriceCenterField(
                      controller: priceController,
                      onChanged: applyPriceFromField,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(14),
                    child: IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final cur = state.offeredPrice > 0
                            ? state.offeredPrice
                            : (suggested ?? 5);
                        final next = ClientRidePricing.increaseOffered(cur);
                        priceController.text = next.toStringAsFixed(2);
                        rideBloc.add(PriceChanged(next));
                      },
                      icon: const Icon(Icons.add, color: AppTheme.primaryBlue),
                    ),
                  ),
                ],
              ),
              if (suggested != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Tarifa sugerida (categoría y extras): '
                  'S/ ${suggested.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleCategorySection extends StatelessWidget {
  const VehicleCategorySection({
    super.key,
    required this.state,
  });

  final ClientRideState state;

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tipo de vehículo',
          style: TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        _VehicleCategoryTile(
          rideBloc: rideBloc,
          state: state,
          category: ClientVehicleCategory.standard,
          title: 'Estándar',
          subtitle:
              'Viaje habitual, buen precio. Ideal hasta 4 personas cómodas.',
          carIcon: Icons.directions_car_outlined,
        ),
        _VehicleCategoryTile(
          rideBloc: rideBloc,
          state: state,
          category: ClientVehicleCategory.comfort,
          title: 'Confort',
          subtitle:
              'Vehículo más amplio o cómodo. Tarifa un poco mayor que estándar.',
          carIcon: Icons.directions_car,
        ),
        _VehicleCategoryTile(
          rideBloc: rideBloc,
          state: state,
          category: ClientVehicleCategory.xl,
          title: 'XL (hasta 6 personas)',
          subtitle:
              'Para grupos o maletas grandes. Mayor recargo por espacio extra.',
          carIcon: Icons.airport_shuttle,
        ),
      ],
    );
  }
}

class _VehicleCategoryTile extends StatelessWidget {
  const _VehicleCategoryTile({
    required this.rideBloc,
    required this.state,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.carIcon,
  });

  final ClientRideBloc rideBloc;
  final ClientRideState state;
  final ClientVehicleCategory category;
  final String title;
  final String subtitle;
  final IconData carIcon;

  @override
  Widget build(BuildContext context) {
    final selected = state.vehicleCategory == category;
    final base = state.routeBaseSuggested;
    final categoryPrice = base != null && base > 0
        ? ClientRidePricing.totalSuggested(
            routeBase: base,
            category: category,
            moreThanFourPassengers: state.moreThanFourPassengers,
            babySeat: state.babySeat,
            pet: state.pet,
          )
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => rideBloc.add(VehicleCategoryChanged(category)),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryBlue.withValues(alpha: 0.14)
                  : AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppTheme.primaryBlue : Colors.white12,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  carIcon,
                  size: 34,
                  color: selected ? AppTheme.primaryBlue : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 11,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (categoryPrice != null)
                      Text(
                        'S/ ${categoryPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: selected ? AppTheme.primaryBlue : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
                      const Text(
                        '—',
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      'Llega en ~4 min',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ReadyToRequestBottomBar extends StatelessWidget {
  const ReadyToRequestBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final rideBloc = context.read<ClientRideBloc>();
    return BlocBuilder<ClientRideBloc, ClientRideState>(
      buildWhen: (p, c) => p != c,
      builder: (context, state) {
        final isSubmitting = state.status == ClientRideStatus.requesting;
        return Material(
          color: const Color(0xFF0F0F0F),
          elevation: 16,
          shadowColor: Colors.black54,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => showClientPaymentMethodPicker(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: ClientPaymentMethodImage(
                            method: state.paymentMethod,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () {
                        final authState = context.read<AuthBloc>().state;
                        if (authState is! AuthAuthenticated) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Debes iniciar sesión para pedir un viaje',
                              ),
                              backgroundColor: AppTheme.errorRed,
                            ),
                          );
                          return;
                        }
                        rideBloc.add(SubmitRideRequest(authState.user.id));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4FF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Text(
                              'Pedir Lleva',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        onPressed: () =>
                            showClientRidePreferencesSheet(context, state),
                        icon: const Icon(
                          Icons.tune,
                          color: AppTheme.primaryBlue,
                        ),
                        tooltip: 'Preferencias del viaje',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hoja deslizable + barra inferior cuando el estado es
/// [ClientRideStatus.readyToRequest] (el atrás está en [MapRouteSummaryBar]).
class ReadyToRequestLayer extends StatefulWidget {
  const ReadyToRequestLayer({
    super.key,
    required this.priceController,
  });

  final TextEditingController priceController;

  @override
  State<ReadyToRequestLayer> createState() => _ReadyToRequestLayerState();
}

class _ReadyToRequestLayerState extends State<ReadyToRequestLayer> {
  static const double _rideReadyBottomBarHeight = 74;
  static const double _kReadyVehicleBlockEstimatePx = 280;

  final GlobalKey _readyFareSectionKey = GlobalKey();
  final GlobalKey _readyPanelHeaderKey = GlobalKey();
  final GlobalKey _readyPanelOuterContentKey = GlobalKey();

  double _readyRequestPanelExtent = 0.38;
  double _readyRequestPanelMinChildSize = 0.38;
  double _readyRequestPanelMaxChildSize = 0.55;

  double _rideRequestPanelBottomInset(BuildContext context) {
    return _rideReadyBottomBarHeight + MediaQuery.paddingOf(context).bottom;
  }

  void _syncReadyPanelExtents(double slotHeight, bool showVehicleTypes) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fareBox =
          _readyFareSectionKey.currentContext?.findRenderObject() as RenderBox?;
      if (fareBox == null || !fareBox.hasSize) return;

      final headerBox = _readyPanelHeaderKey.currentContext?.findRenderObject()
          as RenderBox?;
      final headerH = (headerBox != null && headerBox.hasSize)
          ? headerBox.size.height
          : 52.0;
      final fareH = fareBox.size.height;
      // Mínimo: asa + título + cuadro de precio y texto "Tarifa sugerida" visibles.
      const scrollBottomPad = 8.0;
      final minPx = headerH + fareH + scrollBottomPad;
      final nextMin = (minPx / slotHeight).clamp(0.12, 0.95);

      double maxPx;
      if (showVehicleTypes) {
        final outer = _readyPanelOuterContentKey.currentContext
            ?.findRenderObject() as RenderBox?;
        if (outer != null && outer.hasSize) {
          maxPx = outer.size.height + 2;
        } else {
          maxPx = minPx + 2 + _kReadyVehicleBlockEstimatePx;
        }
      } else {
        maxPx = minPx + 2 + _kReadyVehicleBlockEstimatePx;
      }
      final nextMax = (maxPx / slotHeight).clamp(nextMin + 0.02, 1.0);

      if ((nextMin - _readyRequestPanelMinChildSize).abs() > 0.008 ||
          (nextMax - _readyRequestPanelMaxChildSize).abs() > 0.008) {
        setState(() {
          _readyRequestPanelMinChildSize = nextMin;
          _readyRequestPanelMaxChildSize = nextMax;
          if (_readyRequestPanelExtent < nextMin) {
            _readyRequestPanelExtent = nextMin;
          }
          if (_readyRequestPanelExtent > nextMax) {
            _readyRequestPanelExtent = nextMax;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    // Hueco máximo reservado bajo la UI (fracción de pantalla). Las fracciones
    // min/max/extent del panel son relativas a esta altura "slot".
    final slotHeight = h * 0.46;
    final showVehicleTypes = _readyRequestPanelExtent >=
        (_readyRequestPanelMinChildSize + 0.08);
    _syncReadyPanelExtents(slotHeight, showVehicleTypes);

    final minF = _readyRequestPanelMinChildSize;
    final maxF = _readyRequestPanelMaxChildSize;
    final panelPixelHeight =
        (slotHeight * _readyRequestPanelExtent.clamp(minF, maxF)).clamp(
      120.0,
      slotHeight * maxF,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: _rideRequestPanelBottomInset(context) + 2,
            ),
            child: Material(
              color: Colors.transparent,
              elevation: 12,
              shadowColor: Colors.black54,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: BlocBuilder<ClientRideBloc, ClientRideState>(
                builder: (ctx, st) {
                  if (st.status != ClientRideStatus.readyToRequest) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    height: panelPixelHeight,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (!mounted) return;
                        final dy = details.primaryDelta ?? 0;
                        if (dy == 0) return;
                        final atMax =
                            (_readyRequestPanelExtent - maxF).abs() < 0.015;
                        // When panel is fully expanded and user drags UP, let the inner
                        // SingleChildScrollView handle it instead of resizing the panel.
                        if (atMax && dy < 0) return;
                        setState(() {
                          _readyRequestPanelExtent =
                              (_readyRequestPanelExtent - dy / slotHeight)
                                  .clamp(minF, maxF);
                        });
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            key: _readyPanelHeaderKey,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[600],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Tarifa',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.darkTextSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final atMinHeight =
                                    (_readyRequestPanelExtent - minF).abs() <
                                        0.015;
                                return SingleChildScrollView(
                                  physics: atMinHeight
                                      ? const NeverScrollableScrollPhysics()
                                      : const ClampingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: atMinHeight
                                          ? constraints.maxHeight
                                          : 0,
                                    ),
                                    child: Padding(
                                      key: _readyPanelOuterContentKey,
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        0,
                                        12,
                                        16,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            key: _readyFareSectionKey,
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(
                                                8,
                                                0,
                                                8,
                                                8,
                                              ),
                                              child: RidePriceSection(
                                                priceController:
                                                    widget.priceController,
                                                state: st,
                                              ),
                                            ),
                                          ),
                                          if (showVehicleTypes) ...[
                                            const SizedBox(height: 2),
                                            Padding(
                                              padding: const EdgeInsets.fromLTRB(
                                                8,
                                                0,
                                                8,
                                                8,
                                              ),
                                              child: VehicleCategorySection(
                                                state: st,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ReadyToRequestBottomBar(),
        ),
      ],
    );
  }
}
