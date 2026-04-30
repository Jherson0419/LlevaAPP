import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/keys/app_overlay_keys.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/document_review_status.dart';
import '../../../domain/entities/user.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/driver/document_picker_widget.dart';

const _kLicenseCategories = ['A-I', 'A-IIa', 'A-IIb', 'A-III'];

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
  final _formLegal = GlobalKey<FormState>();

  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();

  String? _licenseCategory;
  DateTime? _soatExpiration;
  DateTime? _propertyExpiration;
  DateTime? _technicalExpiration;

  File? _profilePic;
  File? _dniFront;
  File? _dniBack;
  File? _licenseDoc;
  File? _soatDoc;
  File? _propertyDoc;

  int _currentStep = 0;
  bool _overlayLoading = false;
  bool _awaitingBlocResult = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final target = widget.initialDocumentToFix?.trim();
    if (target == null || target.isEmpty) return;
    _currentStep = 2;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _openPickerForDocument(target);
    });
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _plateCtrl.dispose();
    _colorCtrl.dispose();
    _yearCtrl.dispose();
    _licenseNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final first = DateTime(2000);
    final last = DateTime(now.year + 8);
    final d = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.black,
              surface: AppTheme.darkSurface,
              onSurface: AppTheme.darkText,
            ),
          ),
          child: child!,
        );
      },
    );
    if (d != null) onPicked(d);
  }

  bool _validateLegal() {
    if (_licenseCategory == null || _licenseCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la categoría de licencia'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return false;
    }
    if (_soatExpiration == null ||
        _propertyExpiration == null ||
        _technicalExpiration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa las tres fechas de vencimiento'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return false;
    }
    return _formLegal.currentState?.validate() ?? false;
  }

  bool _validateDocuments() {
    final missing = <String>[];
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    bool hasImage(File? localFile, String? remoteUrl) {
      if (localFile != null) return true;
      return remoteUrl != null && remoteUrl.trim().isNotEmpty;
    }

    if (!hasImage(_profilePic, user?.profilePicUrl)) missing.add('Foto de perfil');
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
      licenseCategory: _licenseCategory,
      licenseNumber: _licenseNumberCtrl.text.trim(),
      soatExpiration: _soatExpiration,
      propertyCardExpiration: _propertyExpiration,
      technicalReviewExpiration: _technicalExpiration,
      profilePicUrl: profileUrl,
      dniFrontUrl: dniFrontUrl,
      dniBackUrl: dniBackUrl,
      licenseUrl: licenseUrl,
      soatUrl: soatUrl,
      propertyCardUrl: propertyUrl,
      dniFrontStatus:
          _dniFront != null ? DocumentReviewStatus.pending.value : baseModel.dniFrontStatus,
      dniBackStatus: _dniBack != null
          ? DocumentReviewStatus.pending.value
          : baseModel.dniBackStatus,
      licenseStatus:
          _licenseDoc != null ? DocumentReviewStatus.pending.value : baseModel.licenseStatus,
      soatStatus: _soatDoc != null ? DocumentReviewStatus.pending.value : baseModel.soatStatus,
      propertyCardStatus: _propertyDoc != null
          ? DocumentReviewStatus.pending.value
          : baseModel.propertyCardStatus,
    );

    if (!mounted) return;
    context.read<AuthBloc>().add(SubmitDriverApplicationEvent(application));
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (!(_formVehicle.currentState?.validate() ?? false)) return;
      setState(() => _currentStep++);
      return;
    }
    if (_currentStep == 1) {
      if (!_validateLegal()) return;
      setState(() => _currentStep++);
      return;
    }
    _finalize();
  }

  void _onStepCancel() {
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    setState(() => _currentStep--);
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
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Solicitud enviada'),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/client-dashboard');
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
            body: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _onStepCancel,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Atrás'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          _currentStep == 2 ? 'Finalizar' : 'Siguiente',
                        ),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text(
                    'Vehículo',
                    style: TextStyle(color: AppTheme.darkText),
                  ),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formVehicle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _brandCtrl,
                          style: const TextStyle(color: AppTheme.darkText),
                          decoration: _fieldDecoration(
                            'Marca',
                            icon: Icons.directions_car_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa la marca';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _modelCtrl,
                          style: const TextStyle(color: AppTheme.darkText),
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
                          style: const TextStyle(color: AppTheme.darkText),
                          textCapitalization: TextCapitalization.characters,
                          decoration: _fieldDecoration(
                            'Placa',
                            icon: Icons.pin_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa la placa';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _colorCtrl,
                          style: const TextStyle(color: AppTheme.darkText),
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
                          style: const TextStyle(color: AppTheme.darkText),
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
                Step(
                  title: const Text(
                    'Legales',
                    style: TextStyle(color: AppTheme.darkText),
                  ),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: Form(
                    key: _formLegal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use — initialValue no actualiza bien al cambiar selección
                          value: _licenseCategory,
                          dropdownColor: AppTheme.darkSurfaceElevated,
                          decoration: _fieldDecoration('Categoría de licencia'),
                          hint: const Text(
                            'Categoría',
                            style: TextStyle(color: AppTheme.darkTextSecondary),
                          ),
                          items: _kLicenseCategories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: const TextStyle(
                                      color: AppTheme.darkText,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _licenseCategory = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _licenseNumberCtrl,
                          style: const TextStyle(color: AppTheme.darkText),
                          decoration: _fieldDecoration(
                            'Nro. de brevete',
                            icon: Icons.badge_outlined,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Ingresa el número de brevete';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _dateTile(
                          label: 'Vencimiento SOAT',
                          date: _soatExpiration,
                          onTap: () => _pickDate(
                            context,
                            initial: _soatExpiration,
                            onPicked: (d) =>
                                setState(() => _soatExpiration = d),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _dateTile(
                          label: 'Revisión técnica',
                          date: _technicalExpiration,
                          onTap: () => _pickDate(
                            context,
                            initial: _technicalExpiration,
                            onPicked: (d) =>
                                setState(() => _technicalExpiration = d),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _dateTile(
                          label: 'Tarjeta de propiedad',
                          date: _propertyExpiration,
                          onTap: () => _pickDate(
                            context,
                            initial: _propertyExpiration,
                            onPicked: (d) =>
                                setState(() => _propertyExpiration = d),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Step(
                  title: const Text(
                    'Documentos',
                    style: TextStyle(color: AppTheme.darkText),
                  ),
                  isActive: _currentStep >= 2,
                  state: StepState.indexed,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Builder(
                        builder: (context) {
                          final authState = context.watch<AuthBloc>().state;
                          final user =
                              authState is AuthAuthenticated ? authState.user : null;
                          final profileStatus = DocumentReviewStatus.pending;
                          final profileEditable = true;
                          return DocumentPickerWidget(
                            label: 'Foto de perfil',
                            file: _profilePic,
                            remoteImageUrl: user?.profilePicUrl,
                            status: profileStatus,
                            showStatus: false,
                            isEditable: profileEditable,
                            onBlockedTap: _showApprovedBlockedMessage,
                            onFileChanged: (f) => setState(() => _profilePic = f),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final authState = context.watch<AuthBloc>().state;
                          final user =
                              authState is AuthAuthenticated ? authState.user : null;
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
                            onFileChanged: (f) => setState(() => _dniFront = f),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final authState = context.watch<AuthBloc>().state;
                          final user =
                              authState is AuthAuthenticated ? authState.user : null;
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
                            onFileChanged: (f) => setState(() => _dniBack = f),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final authState = context.watch<AuthBloc>().state;
                          final user =
                              authState is AuthAuthenticated ? authState.user : null;
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
                            onFileChanged: (f) => setState(() => _licenseDoc = f),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final authState = context.watch<AuthBloc>().state;
                          final user =
                              authState is AuthAuthenticated ? authState.user : null;
                          final status = _statusFromRaw(
                            user?.soatStatus ?? DocumentReviewStatus.pending.value,
                          );
                          return DocumentPickerWidget(
                            label: 'SOAT',
                            file: _soatDoc,
                            remoteImageUrl: user?.soatUrl,
                            status: status,
                            isEditable: _canEditDocument(status),
                            onBlockedTap: _showApprovedBlockedMessage,
                            onFileChanged: (f) => setState(() => _soatDoc = f),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final authState = context.watch<AuthBloc>().state;
                          final user =
                              authState is AuthAuthenticated ? authState.user : null;
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
                            onFileChanged: (f) => setState(() => _propertyDoc = f),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_overlayLoading)
            Positioned.fill( // ignore: prefer_const_constructors
              child: const ColoredBox(
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

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.darkSurfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.event, color: AppTheme.primaryBlue, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      date != null ? _dateFmt.format(date) : 'Seleccionar',
                      style: TextStyle(
                        color: date != null
                            ? AppTheme.darkText
                            : AppTheme.darkTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
