import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/pending_driver_documents.dart';

const _kLicenseCategories = ['A-I', 'A-IIa', 'A-IIb', 'A-III'];

/// Registro de conductor en 3 pasos: personales → vehículo → documentación al conducir.
class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key, this.initialPhone});

  /// Si viene desde registro de perfil (mismo teléfono verificado).
  final String? initialPhone;

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final PageController _pageController = PageController();
  final List<GlobalKey<FormState>> _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];
  final _scrollController = ScrollController();

  int _step = 0;

  // Paso 1 — personales
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dniController = TextEditingController();

  // Paso 2 — vehículo
  final _carBrandController = TextEditingController();
  final _carModelController = TextEditingController();
  final _carPlateController = TextEditingController();
  final _carYearController = TextEditingController();

  // Paso 3 — conducir
  String? _licenseCategory;
  final _licenseNumberController = TextEditingController();
  DateTime? _soatExpiration;
  DateTime? _propertyCardExpiration;
  DateTime? _technicalReviewExpiration;

  /// Archivos locales; la subida ocurre en [AuthBloc] al crear el perfil.
  XFile? _soatFile;
  XFile? _propertyCardFile;
  XFile? _dniFrontFile;
  XFile? _dniBackFile;
  XFile? _licenseFile;
  XFile? _profilePicFile;

  bool _isLoading = false;
  bool _acceptTerms = false;

  static final _dateDisplay = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    final p = widget.initialPhone?.trim();
    if (p != null && p.isNotEmpty) {
      _phoneController.text = p;
    }
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
              title: const Text('Galería',
                  style: TextStyle(color: AppTheme.darkText)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
              title: const Text('Cámara',
                  style: TextStyle(color: AppTheme.darkText)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocumentImage(void Function(XFile) onPicked) async {
    final source = await _pickImageSource();
    if (source == null) return;
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (xFile != null && mounted) {
      onPicked(xFile);
      setState(() {});
    }
  }

  Widget _documentImageTile({
    required String label,
    required XFile? file,
    required VoidCallback onTapPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.darkTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTapPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 132,
              width: double.infinity,
              alignment: Alignment.center,
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(file.path),
                        width: double.infinity,
                        height: 132,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 40,
                          color: AppTheme.primaryBlue.withValues(alpha: 0.85),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toca para capturar o elegir',
                          style: TextStyle(
                            color: AppTheme.darkTextSecondary.withValues(
                              alpha: 0.9,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dniController.dispose();
    _carBrandController.dispose();
    _carModelController.dispose();
    _carPlateController.dispose();
    _carYearController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  ThemeData _pickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.primaryBlue,
        onPrimary: Colors.black,
        surface: AppTheme.darkSurface,
        onSurface: AppTheme.darkText,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppTheme.darkSurface,
      ),
    );
  }

  Future<void> _pickDate({
    required DateTime? current,
    required void Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) onPicked(picked);
  }

  InputDecoration _decoration({
    required String label,
    Widget? prefixIcon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppTheme.darkTextSecondary),
      hintStyle: TextStyle(
        color: AppTheme.darkTextSecondary.withValues(alpha: 0.7),
      ),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: AppTheme.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _decoration(
          label: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            value != null
                ? _dateDisplay.format(value)
                : 'Toca para seleccionar fecha',
            style: TextStyle(
              color: value != null
                  ? AppTheme.darkText
                  : AppTheme.darkTextSecondary,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _goNext() {
    FocusScope.of(context).unfocus();
    if (!(_formKeys[_step].currentState?.validate() ?? false)) return;
    if (_step == 1) {
      if (_soatFile == null || _propertyCardFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes capturar la foto del SOAT y de la tarjeta de propiedad',
            ),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
    }
    if (_step < 2) {
      setState(() => _step++);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_step > 0) {
      setState(() => _step--);
      _pageController.animateToPage(
        _step,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _onComenzar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKeys[2].currentState?.validate() ?? false)) return;

    if (_licenseCategory == null || _licenseCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona la categoría de tu licencia'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    if (_soatExpiration == null ||
        _propertyCardExpiration == null ||
        _technicalReviewExpiration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona todas las fechas de vencimiento (SOAT, tarjeta de propiedad y revisión técnica)',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_dniFrontFile == null ||
        _dniBackFile == null ||
        _licenseFile == null ||
        _profilePicFile == null ||
        _soatFile == null ||
        _propertyCardFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Captura DNI (ambas caras), licencia, foto de perfil y documentos del paso 2',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await PendingDriverDocuments.save({
        PendingDriverDocuments.dniFrontPath: _dniFrontFile!.path,
        PendingDriverDocuments.dniBackPath: _dniBackFile!.path,
        PendingDriverDocuments.licensePath: _licenseFile!.path,
        PendingDriverDocuments.soatPath: _soatFile!.path,
        PendingDriverDocuments.propertyCardPath: _propertyCardFile!.path,
        PendingDriverDocuments.profilePicPath: _profilePicFile!.path,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudieron guardar los documentos: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final phone = _phoneController.text.trim();
    final carYear = int.parse(_carYearController.text.trim());
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();

    final uri = Uri(
      path: '/sms-verification',
      queryParameters: {
        'phone': phone,
        'role': 'driver',
        'first_name': first,
        'last_name': last,
        'email': _emailController.text.trim(),
        'dni': _dniController.text.trim(),
        'car_brand': _carBrandController.text.trim(),
        'car_model': _carModelController.text.trim(),
        'car_plate': _carPlateController.text.trim(),
        'car_year': '$carYear',
        'soat_expiration': _soatExpiration!.toUtc().toIso8601String(),
        'property_card_expiration':
            _propertyCardExpiration!.toUtc().toIso8601String(),
        'technical_review_expiration':
            _technicalReviewExpiration!.toUtc().toIso8601String(),
        'license_category': _licenseCategory!,
        'license_number': _licenseNumberController.text.trim(),
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        title: Text('Registro (${_step + 1}/3)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 3,
                    minHeight: 4,
                    backgroundColor: AppTheme.darkSurface,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _step == 0
                      ? 'Datos personales'
                      : _step == 1
                          ? 'Datos vehiculares'
                          : 'Datos para conducir',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPersonalStep(),
                _buildVehicleStep(),
                _buildDrivingStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Form(
      key: _formKeys[0],
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: AppTheme.darkText),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(9),
                ],
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  labelStyle:
                      const TextStyle(color: AppTheme.darkTextSecondary),
                  filled: true,
                  fillColor: AppTheme.darkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '+51',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          margin: const EdgeInsets.only(left: 12),
                          color:
                              AppTheme.darkTextSecondary.withValues(alpha: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Ingresa tu teléfono';
                  }
                  if (v.trim().length != 9) return '9 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _firstNameController,
                style: const TextStyle(color: AppTheme.darkText),
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  label: 'Nombre',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Ingresa tu nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                style: const TextStyle(color: AppTheme.darkText),
                textCapitalization: TextCapitalization.words,
                decoration: _decoration(
                  label: 'Apellidos',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Ingresa tus apellidos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: AppTheme.darkText),
                keyboardType: TextInputType.emailAddress,
                decoration: _decoration(
                  label: 'Correo electrónico',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Ingresa tu correo';
                  if (!s.contains('@') || !s.contains('.')) {
                    return 'Correo no válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dniController,
                style: const TextStyle(color: AppTheme.darkText),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                decoration: _decoration(
                  label: 'DNI',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.length != 8) return 'DNI debe tener 8 dígitos';
                  if (int.tryParse(s) == null) return 'Solo números';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _goNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Siguiente',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleStep() {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _carBrandController,
              style: const TextStyle(color: AppTheme.darkText),
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                label: 'Marca',
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa la marca' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _carModelController,
              style: const TextStyle(color: AppTheme.darkText),
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                label: 'Modelo',
                prefixIcon: const Icon(Icons.directions_car),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa el modelo' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _carPlateController,
              style: const TextStyle(color: AppTheme.darkText),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [LengthLimitingTextInputFormatter(12)],
              decoration: _decoration(
                label: 'Placa',
                prefixIcon: const Icon(Icons.pin),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ingresa la placa' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _carYearController,
              style: const TextStyle(color: AppTheme.darkText),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _decoration(
                label: 'Año de fabricación',
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                hint: '2005 o posterior',
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Ingresa el año';
                final y = int.tryParse(s);
                if (y == null || y < 2005 || y > DateTime.now().year + 1) {
                  return 'Año inválido (mín. 2005)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Documentos del vehículo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _documentImageTile(
              label: 'SOAT (foto del certificado)',
              file: _soatFile,
              onTapPick: () => _pickDocumentImage((f) => _soatFile = f),
            ),
            const SizedBox(height: 20),
            _documentImageTile(
              label: 'Tarjeta de propiedad',
              file: _propertyCardFile,
              onTapPick: () => _pickDocumentImage((f) => _propertyCardFile = f),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Atrás'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Siguiente',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDrivingStep() {
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Identificación y licencia',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _documentImageTile(
              label: 'DNI — cara frontal',
              file: _dniFrontFile,
              onTapPick: () => _pickDocumentImage((f) => _dniFrontFile = f),
            ),
            const SizedBox(height: 20),
            _documentImageTile(
              label: 'DNI — cara posterior',
              file: _dniBackFile,
              onTapPick: () => _pickDocumentImage((f) => _dniBackFile = f),
            ),
            const SizedBox(height: 20),
            _documentImageTile(
              label: 'Licencia de conducir (brevete)',
              file: _licenseFile,
              onTapPick: () => _pickDocumentImage((f) => _licenseFile = f),
            ),
            const SizedBox(height: 20),
            _documentImageTile(
              label: 'Foto de perfil del conductor',
              file: _profilePicFile,
              onTapPick: () => _pickDocumentImage((f) => _profilePicFile = f),
            ),
            const SizedBox(height: 24),
            _dateTile(
              label: 'Vencimiento SOAT',
              value: _soatExpiration,
              icon: Icons.calendar_today,
              onTap: () => _pickDate(
                current: _soatExpiration,
                onPicked: (d) => setState(() => _soatExpiration = d),
              ),
            ),
            const SizedBox(height: 16),
            _dateTile(
              label: 'Vencimiento tarjeta de propiedad',
              value: _propertyCardExpiration,
              icon: Icons.description_outlined,
              onTap: () => _pickDate(
                current: _propertyCardExpiration,
                onPicked: (d) => setState(() => _propertyCardExpiration = d),
              ),
            ),
            const SizedBox(height: 16),
            _dateTile(
              label: 'Vencimiento revisión técnica',
              value: _technicalReviewExpiration,
              icon: Icons.fact_check_outlined,
              onTap: () => _pickDate(
                current: _technicalReviewExpiration,
                onPicked: (d) => setState(() => _technicalReviewExpiration = d),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _licenseCategory,
              dropdownColor: AppTheme.darkSurface,
              style: const TextStyle(
                color: AppTheme.darkText,
                fontSize: 16,
              ),
              decoration: _decoration(
                label: 'Categoría de licencia',
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              hint: const Text(
                'Selecciona categoría',
                style: TextStyle(color: AppTheme.darkTextSecondary),
              ),
              items: _kLicenseCategories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _licenseCategory = v),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Selecciona categoría' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseNumberController,
              style: const TextStyle(color: AppTheme.darkText),
              decoration: _decoration(
                label: 'Número de brevete',
                prefixIcon: const Icon(Icons.credit_card),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ingresa el número de brevete';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                  activeColor: AppTheme.primaryBlue,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Acepto los términos y condiciones y la política de privacidad',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _goBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Atrás'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _onComenzar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Comenzar',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
