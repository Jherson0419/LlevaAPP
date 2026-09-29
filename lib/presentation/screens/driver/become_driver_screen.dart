import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/document_review_status.dart';
import '../../../domain/entities/user.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/driver/document_picker_widget.dart';

/// Formatea la placa en vivo como AAA-999: fuerza mayúsculas, descarta
/// cualquier carácter que no sea alfanumérico (incluido un '-' tecleado a
/// mano) y vuelve a insertar el guion en la posición 3 — así el usuario no
/// puede escribirlo ni borrarlo directamente, solo aparece/desaparece según
/// cuántos caracteres alfanuméricos lleve.
class _PlateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final alphanumeric =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited =
        alphanumeric.length > 6 ? alphanumeric.substring(0, 6) : alphanumeric;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 3) buffer.write('-');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

const List<String> _kVehicleBrands = [
  'Acura',
  'Alfa Romeo',
  'Aston Martin',
  'Audi',
  'Bentley',
  'BMW',
  'Bugatti',
  'Buick',
  'Cadillac',
  'Chevrolet',
  'Chrysler',
  'Citroën',
  'Dodge',
  'Ferrari',
  'Fiat',
  'Ford',
  'Genesis',
  'GMC',
  'Honda',
  'Hyundai',
  'Infiniti',
  'Jaguar',
  'Jeep',
  'Kia',
  'Lamborghini',
  'Land Rover',
  'Lexus',
  'Lincoln',
  'Lotus',
  'Maserati',
  'Mazda',
  'McLaren',
  'Mercedes-Benz',
  'Mini',
  'Mitsubishi',
  'Nissan',
  'Opel',
  'Peugeot',
  'Porsche',
  'Ram',
  'Renault',
  'Rolls-Royce',
  'Seat',
  'Skoda',
  'Subaru',
  'Suzuki',
  'Tesla',
  'Toyota',
  'Volkswagen',
  'Volvo',
  'BYD',
  'Chery',
  'Geely',
  'Great Wall',
  'Haval',
  'JAC',
  'MG',
  'Zotye',
];

/// Fase 3: ascenso a conductor (pasajero → solicitud con documentos).
class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({
    super.key,
    this.initialDocumentToFix,
  });

  final String? initialDocumentToFix;

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  static const _docDniFront = 'dniFront';
  static const _docDniBack = 'dniBack';
  static const _docLicense = 'license';
  static const _docSoat = 'soat';
  static const _docPropertyCard = 'propertyCard';

  final _formVehicle = GlobalKey<FormState>();

  final _brandCtrl = TextEditingController();
  final _brandFocusNode = FocusNode();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();

  File? _profilePic;
  File? _dniFront;
  File? _dniBack;
  File? _licenseDoc;
  File? _soatDoc;
  File? _propertyDoc;

  int _currentStep = 0;
  bool _overlayLoading = false;
  bool _awaitingBlocResult = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final target = widget.initialDocumentToFix?.trim();
    if (target != null && target.isNotEmpty) {
      _currentStep = 1;
    }
    _pageController = PageController(initialPage: _currentStep);
    if (target == null || target.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openPickerForDocument(target);
    });
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _brandFocusNode.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<ImageSource?> _pickImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppTheme.primaryBlue),
              title: const Text(
                'Galería',
                style: TextStyle(color: AppTheme.darkText),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
              title: const Text(
                'Cámara',
                style: TextStyle(color: AppTheme.darkText),
              ),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocumentImage(void Function(File) onPicked) async {
    final source = await _pickImageSource();
    if (source == null) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (xFile != null && mounted) {
      onPicked(File(xFile.path));
      setState(() {});
    }
  }

  bool _validateDocuments() {
    final missing = <String>[];
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    bool hasImage(File? localFile, String? remoteUrl) {
      if (localFile != null) return true;
      return remoteUrl != null && remoteUrl.trim().isNotEmpty;
    }

    if (!hasImage(_profilePic, user?.profilePicUrl)) {
      missing.add('Foto de perfil');
    }
    if (!hasImage(_dniFront, user?.dniFrontUrl)) missing.add('DNI frontal');
    if (!hasImage(_dniBack, user?.dniBackUrl)) missing.add('DNI posterior');
    if (!hasImage(_licenseDoc, user?.licenseUrl)) missing.add('Licencia');
    if (!hasImage(_soatDoc, user?.soatUrl)) missing.add('SOAT');
    if (!hasImage(_propertyDoc, user?.propertyCardUrl)) {
      missing.add('Tarjeta de propiedad');
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faltan: ${missing.join(', ')}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _finalize() async {
    if (!_validateDocuments()) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    final baseModel = _userModelFromEntity(authState.user);

    setState(() {
      _overlayLoading = true;
      _awaitingBlocResult = true;
    });

    final storage = di.sl<StorageService>();
    String? profileUrl = baseModel.profilePicUrl;
    String? dniFrontUrl = baseModel.dniFrontUrl;
    String? dniBackUrl = baseModel.dniBackUrl;
    String? licenseUrl = baseModel.licenseUrl;
    String? soatUrl = baseModel.soatUrl;
    String? propertyUrl = baseModel.propertyCardUrl;

    try {
      if (_profilePic != null) {
        profileUrl = await storage.uploadImage(_profilePic!, 'profile_pic');
      }
      if (_dniFront != null) {
        dniFrontUrl = await storage.uploadImage(_dniFront!, 'dni_front');
      }
      if (_dniBack != null) {
        dniBackUrl = await storage.uploadImage(_dniBack!, 'dni_back');
      }
      if (_licenseDoc != null) {
        licenseUrl = await storage.uploadImage(_licenseDoc!, 'license');
      }
      if (_soatDoc != null) {
        soatUrl = await storage.uploadImage(_soatDoc!, 'soat');
      }
      if (_propertyDoc != null) {
        propertyUrl = await storage.uploadImage(_propertyDoc!, 'property_card');
      }
    } catch (e, st) {
      developer.log(
        'BecomeDriver _finalize: fallo al subir documentos para revisión: $e',
        name: 'BecomeDriverScreen',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() {
          _overlayLoading = false;
          _awaitingBlocResult = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir fotos: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    final year = int.tryParse(_yearCtrl.text.trim()) ?? 0;
    final application = baseModel.copyWith(
      id: 'temporal',
      carBrand: _brandCtrl.text.trim(),
      carModel: _modelCtrl.text.trim(),
      carPlate: _plateCtrl.text.trim().toUpperCase(),
      carColor: _colorCtrl.text.trim(),
      carYear: year,
      profilePicUrl: profileUrl,
      dniFrontUrl: dniFrontUrl,
      dniBackUrl: dniBackUrl,
      licenseUrl: licenseUrl,
      soatUrl: soatUrl,
      propertyCardUrl: propertyUrl,
      dniFrontStatus: _dniFront != null
          ? DocumentReviewStatus.pending.value
          : baseModel.dniFrontStatus,
      dniBackStatus: _dniBack != null
          ? DocumentReviewStatus.pending.value
          : baseModel.dniBackStatus,
      licenseStatus: _licenseDoc != null
          ? DocumentReviewStatus.pending.value
          : baseModel.licenseStatus,
      soatStatus: _soatDoc != null
          ? DocumentReviewStatus.pending.value
          : baseModel.soatStatus,
      propertyCardStatus: _propertyDoc != null
          ? DocumentReviewStatus.pending.value
          : baseModel.propertyCardStatus,
    );

    if (!mounted) return;
    context.read<AuthBloc>().add(SubmitDriverApplicationEvent(application));
  }

  InputDecoration _fieldDecoration(String hint, {IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.darkTextSecondary),
      prefixIcon: icon != null
          ? Icon(icon, color: AppTheme.primaryBlue, size: 22)
          : null,
      filled: true,
      fillColor: AppTheme.darkSurfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepPill(index: 0, label: '1. Vehículo'),
          Container(
            width: 40,
            height: 2,
            color: Colors.grey[700],
          ),
          _buildStepPill(index: 1, label: '2. Documentos'),
        ],
      ),
    );
  }

  Widget _buildStepPill({required int index, required String label}) {
    final active = _currentStep == index;
    return Container(
      width: 120,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppTheme.primaryBlue : AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : AppTheme.darkTextSecondary,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _currentStep == 0
              ? [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (!(_formVehicle.currentState?.validate() ?? false)) {
                        return;
                      }
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentStep = 1);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Continuar'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() => _currentStep = 0);
                    },
                    child: const Text('Atrás'),
                  ),
                  ElevatedButton(
                    onPressed: _finalize,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Finalizar'),
                  ),
                ],
        ),
      ),
    );
  }

  DocumentReviewStatus _statusFromRaw(String raw) {
    return DocumentReviewStatus.fromRaw(raw);
  }

  bool _canEditDocument(DocumentReviewStatus status) {
    return status != DocumentReviewStatus.approved;
  }

  void _showApprovedBlockedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Este documento ya fue aprobado y no se puede editar.',
        ),
        backgroundColor: AppTheme.darkSurface,
      ),
    );
  }

  Future<void> _openPickerForDocument(String docKey) async {
    switch (docKey) {
      case _docDniFront:
        await _pickDocumentImage((f) => _dniFront = f);
        break;
      case _docDniBack:
        await _pickDocumentImage((f) => _dniBack = f);
        break;
      case _docLicense:
        await _pickDocumentImage((f) => _licenseDoc = f);
        break;
      case _docSoat:
        await _pickDocumentImage((f) => _soatDoc = f);
        break;
      case _docPropertyCard:
        await _pickDocumentImage((f) => _propertyDoc = f);
        break;
      default:
        return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sube la nueva foto del documento rechazado.'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (prev, curr) {
        if (!_awaitingBlocResult) return false;
        return (curr is AuthAuthenticated && curr.user.isDriverApplicant) ||
            curr is AuthError;
      },
      listener: (context, state) {
        if (!_awaitingBlocResult) return;
        _awaitingBlocResult = false;
        if (mounted) {
          setState(() => _overlayLoading = false);
        }
        if (state is AuthAuthenticated && state.user.isDriverApplicant) {
          context.go('/driver-application-sent');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppTheme.darkBackground,
            appBar: AppBar(
              backgroundColor: AppTheme.darkBackground,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new),
                onPressed: () => context.pop(),
              ),
              title: const Text('Ser conductor'),
            ),
            body: Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formVehicle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Autocomplete<String>(
                                textEditingController: _brandCtrl,
                                focusNode: _brandFocusNode,
                                optionsBuilder: (textEditingValue) {
                                  final query = textEditingValue.text.trim();
                                  if (query.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  final lower = query.toLowerCase();
                                  return _kVehicleBrands.where(
                                    (brand) =>
                                        brand.toLowerCase().contains(lower),
                                  );
                                },
                                fieldViewBuilder: (
                                  context,
                                  textEditingController,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  return TextFormField(
                                    controller: textEditingController,
                                    focusNode: focusNode,
                                    style: const TextStyle(
                                      color: AppTheme.darkText,
                                    ),
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    decoration: _fieldDecoration(
                                      'Marca',
                                      icon: Icons.directions_car_outlined,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Ingresa la marca del vehículo';
                                      }
                                      return null;
                                    },
                                    onFieldSubmitted: (_) => onFieldSubmitted(),
                                  );
                                },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                  final limited = options.take(5).toList();
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      borderRadius: BorderRadius.circular(8),
                                      color: AppTheme.darkSurface,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxHeight: 200,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: limited.length,
                                          itemBuilder: (context, index) {
                                            final option = limited[index];
                                            return ListTile(
                                              title: Text(
                                                option,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                onSelected: (option) {
                                  _brandCtrl.text = option;
                                  _formVehicle.currentState?.validate();
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _modelCtrl,
                                style:
                                    const TextStyle(color: AppTheme.darkText),
                                decoration: _fieldDecoration('Modelo'),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Ingresa el modelo';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _plateCtrl,
                                style:
                                    const TextStyle(color: AppTheme.darkText),
                                keyboardType: TextInputType.visiblePassword,
                                textCapitalization:
                                    TextCapitalization.characters,
                                maxLength: 7,
                                inputFormatters: [_PlateInputFormatter()],
                                decoration: _fieldDecoration(
                                  'Placa',
                                  icon: Icons.pin_outlined,
                                ).copyWith(counterText: ''),
                                validator: (v) {
                                  final s = v?.trim() ?? '';
                                  if (s.isEmpty) {
                                    return 'Ingresa la placa';
                                  }
                                  if (!RegExp(r'^[A-Z0-9]{3}-[A-Z0-9]{3}$')
                                      .hasMatch(s)) {
                                    return 'Formato inválido. Ejemplo: ABC-123';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _colorCtrl,
                                style:
                                    const TextStyle(color: AppTheme.darkText),
                                decoration: _fieldDecoration(
                                  'Color',
                                  icon: Icons.palette_outlined,
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Ingresa el color';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _yearCtrl,
                                keyboardType: TextInputType.number,
                                style:
                                    const TextStyle(color: AppTheme.darkText),
                                decoration: _fieldDecoration(
                                  'Año (≥ 2005)',
                                  icon: Icons.calendar_today_outlined,
                                ),
                                validator: (v) {
                                  final y = int.tryParse(v?.trim() ?? '');
                                  if (y == null) return 'Año inválido';
                                  if (y < 2005) return 'El año debe ser ≥ 2005';
                                  if (y > DateTime.now().year + 1) {
                                    return 'Año no válido';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Builder(
                              builder: (context) {
                                final authState =
                                    context.watch<AuthBloc>().state;
                                final user = authState is AuthAuthenticated
                                    ? authState.user
                                    : null;
                                final profileStatus =
                                    DocumentReviewStatus.pending;
                                final profileEditable = true;
                                return DocumentPickerWidget(
                                  label: 'Foto de perfil',
                                  file: _profilePic,
                                  remoteImageUrl: user?.profilePicUrl,
                                  status: profileStatus,
                                  showStatus: false,
                                  isEditable: profileEditable,
                                  onBlockedTap: _showApprovedBlockedMessage,
                                  onFileChanged: (f) =>
                                      setState(() => _profilePic = f),
                                  guidanceMessage:
                                      'Usa buena iluminación, fondo neutro y '
                                      'que tu rostro sea claramente visible. '
                                      'Evita filtros o fotos de documentos.',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final authState =
                                    context.watch<AuthBloc>().state;
                                final user = authState is AuthAuthenticated
                                    ? authState.user
                                    : null;
                                final status = _statusFromRaw(
                                  user?.dniFrontStatus ??
                                      DocumentReviewStatus.pending.value,
                                );
                                return DocumentPickerWidget(
                                  label: 'DNI frontal',
                                  file: _dniFront,
                                  remoteImageUrl: user?.dniFrontUrl,
                                  status: status,
                                  isEditable: _canEditDocument(status),
                                  onBlockedTap: _showApprovedBlockedMessage,
                                  onFileChanged: (f) =>
                                      setState(() => _dniFront = f),
                                  guidanceMessage:
                                      'Fotografía la parte frontal de tu DNI '
                                      'sobre una superficie plana. Asegúrate '
                                      'que todos los datos sean legibles.',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final authState =
                                    context.watch<AuthBloc>().state;
                                final user = authState is AuthAuthenticated
                                    ? authState.user
                                    : null;
                                final status = _statusFromRaw(
                                  user?.dniBackStatus ??
                                      DocumentReviewStatus.pending.value,
                                );
                                return DocumentPickerWidget(
                                  label: 'DNI posterior',
                                  file: _dniBack,
                                  remoteImageUrl: user?.dniBackUrl,
                                  status: status,
                                  isEditable: _canEditDocument(status),
                                  onBlockedTap: _showApprovedBlockedMessage,
                                  onFileChanged: (f) =>
                                      setState(() => _dniBack = f),
                                  guidanceMessage:
                                      'Fotografía el reverso de tu DNI. El '
                                      'código de barras debe verse con '
                                      'claridad.',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final authState =
                                    context.watch<AuthBloc>().state;
                                final user = authState is AuthAuthenticated
                                    ? authState.user
                                    : null;
                                final status = _statusFromRaw(
                                  user?.licenseStatus ??
                                      DocumentReviewStatus.pending.value,
                                );
                                return DocumentPickerWidget(
                                  label: 'Licencia de conducir',
                                  file: _licenseDoc,
                                  remoteImageUrl: user?.licenseUrl,
                                  status: status,
                                  isEditable: _canEditDocument(status),
                                  onBlockedTap: _showApprovedBlockedMessage,
                                  onFileChanged: (f) =>
                                      setState(() => _licenseDoc = f),
                                  guidanceMessage:
                                      'Captura tu licencia completa y '
                                      'vigente. Verifica que la categoría y '
                                      'fecha de vencimiento sean visibles.',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final authState =
                                    context.watch<AuthBloc>().state;
                                final user = authState is AuthAuthenticated
                                    ? authState.user
                                    : null;
                                final status = _statusFromRaw(
                                  user?.soatStatus ??
                                      DocumentReviewStatus.pending.value,
                                );
                                return DocumentPickerWidget(
                                  label: 'SOAT',
                                  file: _soatDoc,
                                  remoteImageUrl: user?.soatUrl,
                                  status: status,
                                  isEditable: _canEditDocument(status),
                                  onBlockedTap: _showApprovedBlockedMessage,
                                  onFileChanged: (f) =>
                                      setState(() => _soatDoc = f),
                                  guidanceMessage:
                                      'Sube una foto o PDF de tu SOAT '
                                      'vigente. Verifica que la placa '
                                      'coincida con tu vehículo registrado.',
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final authState =
                                    context.watch<AuthBloc>().state;
                                final user = authState is AuthAuthenticated
                                    ? authState.user
                                    : null;
                                final status = _statusFromRaw(
                                  user?.propertyCardStatus ??
                                      DocumentReviewStatus.pending.value,
                                );
                                return DocumentPickerWidget(
                                  label: 'Tarjeta de propiedad',
                                  file: _propertyDoc,
                                  remoteImageUrl: user?.propertyCardUrl,
                                  status: status,
                                  isEditable: _canEditDocument(status),
                                  onBlockedTap: _showApprovedBlockedMessage,
                                  onFileChanged: (f) =>
                                      setState(() => _propertyDoc = f),
                                  guidanceMessage:
                                      'Fotografía la tarjeta de propiedad '
                                      'del vehículo. Debe coincidir con la '
                                      'placa registrada.',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
          if (_overlayLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF00D4FF),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Procesando solicitud…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  UserModel _userModelFromEntity(UserEntity u) {
    return UserModel(
      id: u.id,
      phone: u.phone,
      role: u.role,
      isDriverApplicant: u.isDriverApplicant,
      fullName: u.fullName,
      email: u.email,
      dni: u.dni,
      carPlate: u.carPlate,
      carBrand: u.carBrand,
      carModel: u.carModel,
      isApproved: u.isApproved,
      isBanned: u.isBanned,
      carYear: u.carYear,
      carColor: u.carColor,
      soatExpiration: u.soatExpiration,
      propertyCardExpiration: u.propertyCardExpiration,
      technicalReviewExpiration: u.technicalReviewExpiration,
      licenseCategory: u.licenseCategory,
      licenseNumber: u.licenseNumber,
      birthDate: u.birthDate,
      dniFrontUrl: u.dniFrontUrl,
      dniBackUrl: u.dniBackUrl,
      licenseUrl: u.licenseUrl,
      soatUrl: u.soatUrl,
      propertyCardUrl: u.propertyCardUrl,
      profilePicUrl: u.profilePicUrl,
      dniFrontStatus: u.dniFrontStatus,
      dniBackStatus: u.dniBackStatus,
      licenseStatus: u.licenseStatus,
      soatStatus: u.soatStatus,
      propertyCardStatus: u.propertyCardStatus,
    );
  }
}
